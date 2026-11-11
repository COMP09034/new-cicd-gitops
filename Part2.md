# Part 2: The Package Stage

The commit stage tells us the code works and is safe. Now we package it as a **container image**, the release candidate that can be deployed to any environment.

## 2.1 Configure Repository Permissions

The workflow needs permission to push packages.

1. In your repository go to **Settings → Actions → General**
2. Under **Workflow permissions**, select **Read and write permissions**
3. Click **Save**

## 2.2 Add the Package Job

Edit `.github/workflows/commit-stage.yml`.

First add an `env` block after the `on:` block. Using `github.repository` means the image is named after your repo, i.e. `ghcr.io/comp09034-26/catalog-service-USERNAME`:

```yaml
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
```

Then add the `package` job after the `build` job:

```yaml
  package:
    needs: build
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout source code
        uses: actions/checkout@v4

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract image metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=
            type=raw,value=latest

      - name: Build and push image
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

Key points:

- `needs: build` - packaging only runs if tests and scans pass.
- `if: ... refs/heads/main` - only merged code on `main` is packaged, not feature branches or PRs.
- `GITHUB_TOKEN` is provided automatically; `packages: write` lets it push images.
- **Tags**: the short commit SHA (exact traceability to code) and `latest` (convenient, but avoid in production).

Commit and push to `main`. In **Actions**, `build` runs first, then `package` once it succeeds.

## 2.3 Verify the Image

Find the package at `github.com/orgs/COMP09034-26/packages`, and note its tags (a commit SHA and `latest`).

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

## 2.4 Test the Pull Request Flow

Verify that packaging is skipped for unmerged code.

1. Create a branch: `git checkout -b greeting-change`
2. Change the greeting in `HomeController.java`
3. Commit, push the branch, and open a Pull Request
4. In **Actions**, `build` runs and `package` is **skipped**
5. Merge the PR. All jobs now run and a new image is pushed with the merge commit SHA.
6. Clean up: `git checkout main && git pull && git branch -d greeting-change`

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
                        │  (only on main, if build passes)
                        ▼
Package Stage: Build Image → Tag → Push to GHCR
```

This reflects the **Build, Release, Run** principle of the 12-Factor App: the same immutable image is deployed to every environment, and only configuration changes. Part 3 covers the **Run** step.

---

[← Previous: Part 1 - The Commit Stage](./Part1.md) | [Back to README](./README.md) | [Next: Part 3 - GitOps Deployment →](./Part3.md)
