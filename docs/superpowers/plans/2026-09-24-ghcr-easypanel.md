# GHCR EasyPanel Image Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Human Atlas static site into a production Nginx container and publish it automatically to GHCR for EasyPanel deployment.

**Architecture:** A Node 22 Alpine build stage runs the existing locked Vite build. An Nginx Alpine runtime stage serves only `dist/` and applies SPA fallback through a small checked-in config. GitHub Actions uses Buildx and `GITHUB_TOKEN` to publish `ghcr.io/rahmatfadhilah22/human-atlas` with `latest`, commit SHA, and version tags.

**Tech Stack:** Docker multi-stage builds, Nginx Alpine, GitHub Actions, Docker Buildx, Node.js 22, Vite.

---

## File map

- Create `Dockerfile`: reproducible multi-stage build and production image metadata.
- Create `nginx.conf`: static asset serving, SPA fallback, and container health endpoint.
- Create `.dockerignore`: exclude local and repository-only files from the Docker build context.
- Create `.github/workflows/docker-publish.yml`: build and publish GHCR images on `main`, `v*` tags, or manual dispatch.
- Modify `README.md`: document the GHCR image address, port 80, and EasyPanel setup.

## Task 1: Add the production container

**Files:**
- Create: `Dockerfile`
- Create: `nginx.conf`
- Create: `.dockerignore`

- [ ] **Step 1: Create the Docker build file**

Use Node 22 Alpine for the existing `npm ci` + `npm run build` flow, then copy only `dist/` into Nginx Alpine:

```dockerfile
FROM node:22-alpine AS build

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:1.29-alpine

LABEL org.opencontainers.image.source="https://github.com/rahmatfadhilah22/human-atlas"
LABEL org.opencontainers.image.description="Human Atlas interactive 3D anatomy explorer"
LABEL org.opencontainers.image.licenses="MIT"

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80
```

- [ ] **Step 2: Add Nginx routing and caching configuration**

Create `nginx.conf` with a health endpoint, SPA fallback, and immutable caching for Vite fingerprinted assets:

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location = /healthz {
        access_log off;
        add_header Content-Type text/plain;
        return 200 'ok\n';
    }

    location /assets/ {
        try_files $uri =404;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

- [ ] **Step 3: Exclude irrelevant files from the build context**

Create `.dockerignore`:

```text
.git
.github
node_modules
dist
.vercel
.wrangler
outputs
work
*.tsbuildinfo
.env*
README.md
docs
```

- [ ] **Step 4: Build the image locally**

Run:

```text
docker build -t human-atlas:local .
```

Expected: the build completes successfully and ends with a tagged `human-atlas:local` image.

- [ ] **Step 5: Run and smoke-test the container**

Run:

```text
docker run --rm -d --name human-atlas-test -p 8080:80 human-atlas:local
docker run --rm --network host curlimages/curl:8.12.1 -fsS http://127.0.0.1:8080/healthz
docker run --rm --network host curlimages/curl:8.12.1 -fsS http://127.0.0.1:8080/
docker run --rm --network host curlimages/curl:8.12.1 -fsS http://127.0.0.1:8080/nonexistent-client-route
 docker rm -f human-atlas-test
```

Expected: `/healthz` returns `ok`, `/` returns HTML, and the client route returns the same SPA HTML with HTTP 200. On Windows Docker Desktop, if `--network host` is unavailable, execute the three curl requests from the host instead and then remove the container with `docker rm -f human-atlas-test`.

- [ ] **Step 6: Commit the container files**

```text
git add Dockerfile nginx.conf .dockerignore
git commit -m "feat: add production container for GHCR" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Task 2: Publish images to GHCR

**Files:**
- Create: `.github/workflows/docker-publish.yml`

- [ ] **Step 1: Create the GitHub Actions workflow**

```yaml
name: Publish container image

on:
  push:
    branches: [main]
    tags: ['v*']
  workflow_dispatch:

permissions:
  contents: read
  packages: write

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=raw,value=latest,enable={{is_default_branch}}
            type=sha,prefix=sha-,format=short
            type=ref,event=tag

      - name: Build and push image
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

- [ ] **Step 2: Validate the workflow source locally**

Run:

```text
npm run check
npm run build
```

Expected: both commands exit successfully. The workflow itself is validated by GitHub Actions on the next push; no extra workflow parser dependency is added.

- [ ] **Step 3: Commit the workflow**

```text
git add .github/workflows/docker-publish.yml
git commit -m "ci: publish images to GHCR" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Task 3: Document EasyPanel deployment

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add the GHCR deployment section**

Add after the existing deployment paragraph:

```markdown
### EasyPanel via GHCR

The GitHub Actions workflow publishes the container image to:

```text
ghcr.io/rahmatfadhilah22/human-atlas:latest
```

In EasyPanel, create a Docker Image service with that image and expose container port `80`. Use a commit tag such as `sha-<short-commit>` when a pinned deployment is preferred. If the GHCR package is private, configure EasyPanel with a GitHub token that has package read access; public packages require no registry credentials.
```

- [ ] **Step 2: Verify the documentation matches the workflow**

Confirm the image path is `ghcr.io/rahmatfadhilah22/human-atlas`, the runtime port is `80`, and the workflow produces `latest` on the default branch plus `sha-<short-commit>` tags.

- [ ] **Step 3: Run the final checks**

Run:

```text
npm run check
npm run build
```

Expected: both commands pass.

- [ ] **Step 4: Commit the documentation**

```text
git add README.md
git commit -m "docs: explain EasyPanel GHCR deployment" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Final verification

- [ ] Confirm `git status --short` is clean.
- [ ] Confirm the GitHub Actions workflow has `packages: write` permission.
- [ ] Confirm the first workflow run publishes `ghcr.io/rahmatfadhilah22/human-atlas:latest`.
- [ ] In EasyPanel, set the image to that address and container port to `80`.
