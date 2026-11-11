# Part 2: The Package Stage

The commit stage tells us the code works and is safe. Now we package it as a **container image**, the release candidate that can be deployed to any environment.

## 2.1 Configure Repository Permissions

The workflow needs permission to push packages.

1. In your repository go to **Settings → Actions → General**
2. Under **Workflow permissions**, select **Read and write permissions**
3. Click **Save**

## 2.2 Add the Package Workflow

The package stage is a **separate workflow** that runs after the Commit Stage workflow succeeds. Create `.github/workflows/package-stage.yaml`:

```yaml
name: Package Stage

on:
  workflow_run:
    workflows: ["Commit Stage"]
    types: [completed]
    branches: [main]

jobs:
  package:
    if: github.event.workflow_run.conclusion == 'success' && github.event.workflow_run.event == 'push'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout source code
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.workflow_run.head_sha }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract image metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=raw,value=${{ github.event.workflow_run.head_sha }}
            type=raw,value=latest

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

Key points:

- `workflows: ["Commit Stage"]` - this must match the `name:` of your commit stage workflow exactly. The Package Stage starts when that workflow completes on `main`.
- `if: ... conclusion == 'success' && ... event == 'push'` - packaging only runs if the commit stage passed (build, tests and scan) and was triggered by a push, not a manual run.
- `ref: ${{ github.event.workflow_run.head_sha }}` - a `workflow_run` workflow would otherwise check out the latest commit on the default branch. Using `head_sha` builds the exact commit that was tested. `github.event.workflow_run` is part of the event payload GitHub sends when it triggers this workflow; you don't define it anywhere.
- `GITHUB_TOKEN` is provided automatically; `packages: write` lets it push images.
- The image is named after your repo, `ghcr.io/${{ github.repository }}`, i.e. `ghcr.io/comp09034-26/catalog-service-USERNAME`. The metadata action lowercases the name for you.
- **Tags**: the full commit SHA (exact traceability to code) and `latest` (convenient, but avoid in production).
- **Caching**: `cache-from` and `cache-to` store Docker layers in the GitHub Actions cache so later builds are faster.
- The image is built from the `Dockerfile` in the repository root. It builds the jar with the Gradle wrapper and runs it as a non-root user.

Because this workflow is triggered by `workflow_run`, GitHub only uses the version on the default branch (`main`). Changes to it take effect once they are on `main`.

Commit and push to `main`. In **Actions**, **Commit Stage** runs first, then **Package Stage** starts once it succeeds.

## 2.3 Verify the Image

Find the package at `github.com/orgs/COMP09034-26/packages`, and note its tags (the full commit SHA and `latest`).

To run it locally, first log in with a Personal Access Token (classic) with `read:packages` scope (**Settings → Developer settings → Personal access tokens**). Never commit tokens to git.

```bash
echo YOUR_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

docker pull ghcr.io/comp09034-26/catalog-service-USERNAME:latest
docker run --rm -p 9001:9001 ghcr.io/comp09034-26/catalog-service-USERNAME:latest
```

In another terminal:

```bash
curl localhost:9001/
```

Stop the container with `Ctrl+C` (`--rm` removes it).

## 2.4 Test the Branch Flow

Verify that packaging is skipped for unmerged code. The Commit Stage runs on every push, but the Package Stage only runs for the `main` branch.

1. Create a branch: `git checkout -b greeting-change`
2. Change the greeting in `HomeController.java`
3. Commit and push the branch
4. In **Actions**, **Commit Stage** runs on the branch and **Package Stage** does **not** run
5. Open a Pull Request and merge it into `main`
6. In **Actions**, **Commit Stage** runs on `main`, then **Package Stage** runs and pushes a new image tagged with the merge commit SHA
7. Clean up: `git checkout main && git pull && git branch -d greeting-change`

## 2.5 Image Tagging Strategies

| Strategy | Example | Pros | Cons |
| -------- | ------- | ---- | ---- |
| `latest` | `app:latest` | Convenient | No traceability, risky in production |
| Semantic version | `app:v1.2.3` | Meaningful | Manual management |
| Commit SHA | `app:abc123f` | Exact traceability | Not human-friendly |
| Branch + SHA | `app:main-abc123f` | Context + traceability | Longer |

If there's a bug in production, the SHA tag lets you run `git show abc123f` to see exactly what code is running and reproduce it locally. This is impossible with only `latest`. **In production, always reference images by SHA.**

## 2.6 The Pipeline So Far

```text
Commit Stage:  Build → Test → Vulnerability Scan
                        │  (workflow_run: only on main, if Commit Stage succeeds)
                        ▼
Package Stage: Build Image → Tag → Push to GHCR
```

This reflects the **Build, Release, Run** principle of the 12-Factor App: the same immutable image is deployed to every environment, and only configuration changes. Part 3 covers the **Run** step.

---

[← Previous: Part 1 - The Commit Stage](./Part1.md) | [Back to README](./README.md) | [Next: Part 3 - GitOps Deployment →](./Part3.md)
