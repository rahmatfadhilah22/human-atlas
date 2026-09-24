# GHCR Image for EasyPanel

## Goal

Publish the Human Atlas static Vite build as a container image to GitHub Container Registry (GHCR), ready to deploy in EasyPanel by image address alone.

## Design

Use a two-stage Docker build. The build stage uses Node.js 22 Alpine, installs the locked dependencies with `npm ci`, and runs `npm run build`. The runtime stage uses Nginx Alpine and contains only the generated `dist/` files plus a small Nginx configuration.

Nginx serves the static assets, applies SPA fallback to `/index.html`, exposes port 80, and runs with the default Nginx foreground command. No Node.js runtime is included in production.

The GitHub Actions workflow runs on pushes to `main`, version tags (`v*`), and manual dispatch. It authenticates to GHCR with the repository-provided `GITHUB_TOKEN`, builds with Docker Buildx, and publishes `ghcr.io/rahmatfadhilah22/human-atlas` with `latest`, an immutable commit-SHA tag, and a semantic version tag when the workflow is triggered by a version tag. GitHub Actions cache is used for Docker layers.

## EasyPanel usage

EasyPanel can pull:

- `ghcr.io/rahmatfadhilah22/human-atlas:latest`
- `ghcr.io/rahmatfadhilah22/human-atlas:<commit-sha>` for a pinned deployment

The container listens on port 80. If the GHCR package is private, EasyPanel must be given a GitHub registry credential with package-read access; a public package needs no credential.

## Validation

Run `npm run check` and `npm run build` locally. Validate the container build with `docker build -t human-atlas:local .`; if Docker is available, run the container and request `/` and a client-side route to confirm static serving and SPA fallback.

## Scope

No compose file, Node production server, deployment hook, or automatic GHCR package visibility change is included. EasyPanel configuration remains external to this repository.
