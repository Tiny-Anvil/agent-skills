---
description: Deploy a published image version to one environment (GitOps PR, Azure Container Apps or other) and verify it runs there.
argument-hint: <app> <env> <version>
disable-model-invocation: true
---

Invoke the anvil:deploying-container-images skill and follow it exactly as presented to you. Respect the deploy gates of the run's RULES.md if there is one; higher environments (acc, prod) need the owner's explicit go in this conversation. Deploy:

$ARGUMENTS
