# One image serves both the API and the SPA. The Vue app is built into wwwroot/ and served from the API's origin,
# which is why the API needs no CORS.
# The build stages run on the builder's own platform ($BUILDPLATFORM) and cross-compile for $TARGETARCH, so a
# multi-arch build on an x64 runner only emulates the final stage (one apt-get and the COPYs), not pnpm or dotnet.
#
#   docker compose up -d --build --wait
#   docker buildx build --platform linux/amd64,linux/arm64 --build-arg VERSION=v1.2.3 .

ARG VERSION=local

# ---------- SPA ----------
FROM --platform=$BUILDPLATFORM node:22-alpine AS spa
WORKDIR /src
RUN corepack enable
ARG VERSION
ENV VITE_APP_VERSION=$VERSION
# The browser download is never needed in the image.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
# Manifests first, so pnpm install stays cached until a dependency changes.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY src/apps/app/package.json src/apps/app/
RUN pnpm install --frozen-lockfile
COPY src/apps/app/ src/apps/app/
RUN pnpm --filter @<scope>/<app>-app build

# ---------- API ----------
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:10.0 AS api
ARG TARGETARCH
WORKDIR /src
COPY global.json nuget.config Directory.Build.props Directory.Build.targets Directory.Packages.props ./
COPY src/apps/api/<Org>.<App>.Api.csproj src/apps/api/
COPY src/aspire/<Org>.<App>.ServiceDefaults/<Org>.<App>.ServiceDefaults.csproj src/aspire/<Org>.<App>.ServiceDefaults/
# Private feed? RUN --mount=type=secret,id=nuget ... credit the source here; never as a build-arg.
RUN dotnet restore src/apps/api/<Org>.<App>.Api.csproj -a $TARGETARCH
COPY src/aspire/<Org>.<App>.ServiceDefaults/ src/aspire/<Org>.<App>.ServiceDefaults/
COPY src/apps/api/ src/apps/api/
RUN dotnet publish src/apps/api/<Org>.<App>.Api.csproj -c Release --no-restore -a $TARGETARCH --self-contained false -o /app/publish

# ---------- Runtime ----------
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
# Npgsql loads libgssapi_krb5 (GSS encryption/Kerberos); without it every start logs "Cannot load library
# libgssapi_krb5.so.2". Drop this RUN when the app does not use Npgsql.
RUN apt-get update \
 && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ARG VERSION
ENV APP_VERSION=$VERSION
# The listen address comes from Kestrel:Endpoints in configuration. Clear the base image's default so Kestrel
# does not warn "Overriding address(es)" on every start.
ENV ASPNETCORE_HTTP_PORTS=

COPY --from=api /app/publish ./
COPY --from=spa /src/src/apps/app/dist ./wwwroot/
# ConfigurationGuard expects the placeholder-bearing template as appsettings.json and refuses to start while any
# __SET_AT_RUNTIME__ value is not overridden by an environment variable.
COPY src/apps/api/appsettings.example.json ./appsettings.json

EXPOSE 8080
USER $APP_UID
ENTRYPOINT ["dotnet", "<Org>.<App>.Api.dll"]
