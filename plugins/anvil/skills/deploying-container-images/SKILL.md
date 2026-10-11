---
name: deploying-container-images
description: Use when a versioned container image already in a registry has to reach an environment (test, acc, prod) — bumping the image tag in a GitOps repo (Kustomize or Helm, Argo CD or Flux) through a pull request, deploying to Azure Container Apps, or another target — or when a pipeline is green but the environment does not run the new version, a rollback is needed, or someone wants to deploy a moving tag like :latest.
---

# Deploying Container Images

## Overview

Delivery (github-cicd-dotnet-vue) ends with `<registry>/<image>:<version>` in a registry. This skill takes that
exact version to an environment and **proves the environment runs it**. Three paths, chosen at setup and recorded
in RULES.md:

| Path | A deploy is | Rollback |
|---|---|---|
| **GitOps PR** (Kustomize/Helm + Argo CD/Flux) | a PR that changes one tag in one environment's file | revert the PR |
| **Azure Container Apps** | a deploy job (OIDC login) that sets the image to the version | rerun with the previous version |
| **Other** (Compose on a host, Nomad, Fly, a PaaS) | the owner's mechanism, held to the contract below | the previous version, same mechanism |

**The contract every path keeps:**
1. Deploy a **version tag**, never `:latest`/`:dev` (a moving tag cannot be rolled back and may not redeploy).
2. One environment per change; higher environments (acc, prod) only through a review checkpoint.
3. Secrets by name only. The owner creates the values (Sealed Secrets, SOPS, External Secrets, Key Vault, ...).
4. **Verified on the environment** (below), not by a green pipeline.

## Path 1: GitOps PR

Read the GitOps repo's own README / CLAUDE.md first. It decides the layout, how secrets are made, which ports or
hostnames are free, and what the cluster requires (architecture `nodeSelector`, pull secrets, resource limits).

**Manual bumps, by design.** CI only builds images; a person (or the run, within its gates) opens a PR that changes
the tag. No image-updater bot: sometimes the newest image is not the one you want, and the PR is the record of who
deployed what, when.

1. **First deploy** (one PR): the app's base (Deployment, Service, Ingress) and one overlay per environment
   (namespace, `images: newTag: <version>`, host, ConfigMap with non-secret settings, secret references), plus the
   registration the GitOps repo uses (an Argo CD `Application`, a Flux `Kustomization`, a line in a parent
   kustomization). Templates: `templates/gitops/base-deployment.yaml`, `templates/gitops/overlay-kustomization.yaml`.
   - Pods: non-root `securityContext`, requests + a memory limit, liveness/readiness on the health endpoint with an
     `initialDelaySeconds` that covers migrations on start, `strategy: Recreate` when the app runs one replica
     with migrate-on-startup.
   - The image name lives in the base; overlays change **only** `newTag` (one source of truth, no copied names).
2. **Every later deploy:** `templates/gitops/bump.sh <app> <env> <version>` — checks the image tag exists in the
   registry, branches `deploy/<app>-<env>-<version>`, changes `newTag`, renders the overlay, commits
   `deploy(<app>): <env> <old> → <new>`, pushes and opens the PR. Nothing else changes in that PR.
3. **Validate before the PR:** `kubectl kustomize <overlay>` (or `helm template`) succeeds for every changed
   environment. Many GitOps repos run this in CI too.
4. **Merge** only if RULES.md allows it for this environment; otherwise stop at a review with the PR link.
5. Wait for the sync (Argo CD / Flux), then verify.

## Path 2: Azure Container Apps

`templates/azure-container-apps/deploy.yml`: on `release: released` (or `workflow_dispatch` with a version), a job
in a **GitHub Environment** (`production` with required reviewers, or per environment) logs in with **federated
OIDC** (`azure/login` with `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` as variables; no client
secret) and runs `az containerapp update --image <registry>/<image>:<version>`.
- Pull from ACR with the Container App's **managed identity** (`AcrPull`), not admin credentials.
- Database and other secrets via managed identity or Key Vault references, not values in the workflow.
- **The run never creates** the identity, the federated credential, the GitHub Environment or Azure resources. It
  writes the Bicep / `az` scripts and stops at a review for the owner to run them.

## Path 3: Other

Write down in RULES.md how a version gets onto the environment (a command or a PR), how to read back which version
runs there, and how to roll back. Then keep the contract above. Examples: `docker compose pull && up -d` on a host
with `APP_IMAGE_TAG=<version>`; `fly deploy --image ...`; a Nomad job with a pinned tag.

## Verifying a Deploy

A green pipeline proves the image exists. It does not prove the environment runs it.

```bash
templates/verify-deploy.sh https://<host> <version>     # health 200, served version == <version>, API 404s are JSON
```

It checks, and you record each output in the increment:
- `GET /api/v1/health` → 200;
- the version the environment serves (`/api/v1/version` or `/api/v1/config` → `apiVersion`) equals the deployed
  version;
- an unknown `/api/v1/...` route is a 404 problem+json, not the SPA shell;
- with auth: unauthenticated `/api/v1/me` is 401 (a misconfigured auth flag yields 200 for everyone).

Read-only checks on the platform as well, where you have access:

```bash
kubectl -n <ns> get deploy <app> -o jsonpath='{.spec.template.spec.containers[0].image}'   # GitOps
kubectl -n <ns> get pods -l app.kubernetes.io/name=<app>                                     # Ready, no restarts
az containerapp show -n <app> -g <rg> --query properties.template.containers[0].image         # Container Apps
```

Syncs and rollouts take minutes: poll with a bound (e.g. every 30 s for 10 min) and treat a timeout as a defect to
investigate, not as success.

## Red Flags

| Thought | Reality |
|---|---|
| "Deploy `:latest`, it's simpler" | Pin the version; a moving tag is neither a deploy nor a rollback. |
| "I'll push the overlay change straight to main" | GitOps changes go through a PR, always. |
| "An image updater can bump it for us" | Then nobody chose the version. Bumps are a PR someone merges. |
| "I'll copy the image name into each overlay" | The name lives in the base; overlays change only the tag. |
| "Pipeline green, deployed" | Check the served version and the running image on the environment. |
| "Prod is the same change, I'll do it too" | Higher environments are a review checkpoint. |
| "I'll put the connection string in the ConfigMap for now" | Secrets by name only; the owner makes the values. |
