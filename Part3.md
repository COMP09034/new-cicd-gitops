# Part 3: GitOps Deployment with ArgoCD

Your pipeline now produces tested, scanned, tagged images. This part deploys them to Kubernetes.

**GitOps** makes Git the single source of truth for your deployed state. Instead of running `kubectl apply` manually or pushing from CI, an operator in the cluster (**ArgoCD**) watches your repository and keeps the cluster in sync with it.

Principles: **declarative** (YAML manifests), **versioned** (Git history), **immutable** (SHA-tagged images), **pulled automatically** by the cluster, and **continuously reconciled**.

## 3.1 Prerequisites

- Your image is in GHCR (Part 2)
- A local Kubernetes cluster is running:

```bash
kubectl cluster-info
kubectl get nodes
```

## 3.2 Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
kubectl get pods -n argocd
```

## 3.3 Access the ArgoCD UI

Port-forward the server (keep this terminal open):

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

In a new terminal, get the admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

Open <https://localhost:8080>, accept the self-signed certificate warning, and log in as `admin`.

## 3.4 Allow the Cluster to Pull Your Image

### Option A: make the package public (simplest)

1. Go to `github.com/orgs/<ORG>/packages` and open `<REPO>`
2. **Package settings → Danger Zone → Change visibility → Public**

### Option B: image pull secret (private package)

```bash
kubectl create namespace catalog

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<GITHUB_USER> \
  --docker-password=YOUR_TOKEN \
  -n catalog
```

Then add this under `spec.template.spec` in `k8s/deployment.yaml` (you create this file in section 3.5):

```yaml
imagePullSecrets:
- name: ghcr-secret
```

## 3.5 Create the Kubernetes Manifest

ArgoCD deploys whatever is in the `k8s/` folder of your repository. Create `k8s/deployment.yaml` (replace `<ORG>` and `<REPO>`). Unlike the local `deployment.yaml` in the repository root, it pulls the image from GHCR, so it has no `imagePullPolicy: Never`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: catalog-service
  template:
    metadata:
      labels:
        app: catalog-service
    spec:
      containers:
      - name: catalog-service
        image: ghcr.io/<ORG>/<REPO>:latest
        ports:
        - containerPort: 9001
---
apiVersion: v1
kind: Service
metadata:
  name: catalog-service
spec:
  type: LoadBalancer
  selector:
    app: catalog-service
  ports:
  - port: 9001
    targetPort: 9001
```

The image tag must exist in GHCR. Section 3.9 replaces `latest` with a full commit SHA tag. If you chose Option B above, add the `imagePullSecrets` block now.

Commit and push `k8s/deployment.yaml` to `main`.

## 3.6 Create the ArgoCD Application

Create `argocd-application.yaml` in your repository (replace `<ORG>` and `<REPO>`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: catalog-service
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/COMP09034/new-cicd-gitops.git
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: catalog
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
```

Apply it:

```bash
kubectl apply -f argocd-application.yaml
```

(Alternatively, use **+ NEW APP** in the UI with the same values.)

## 3.7 Initial Sync

The app starts **OutOfSync** because the sync policy is manual. In the UI, open `catalog-service`, click **SYNC**, then **SYNCHRONIZE**.

Watch the deployment and test it:

```bash
kubectl get pods -n catalog -w

kubectl port-forward -n catalog svc/catalog-service 9001:9001
curl http://localhost:9001/        # in another terminal
```

## 3.8 Enable Auto-Sync

Update `argocd-application.yaml` so the `syncPolicy` reads:

```yaml
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

```bash
kubectl apply -f argocd-application.yaml
```

- **Auto-sync**: deploy automatically when Git changes
- **Prune**: delete cluster resources removed from Git
- **Self-heal**: revert manual changes made directly in the cluster

## 3.9 Test the End-to-End Flow

Code change → CI/CD → new image → GitOps deployment.

1. **Change the code** in `HomeController.java`:

   ```java
   @GetMapping("/")
   public String greeting() {
       return "Welcome to the Catalog Service - GitOps Edition";
   }
   ```

2. **Commit and push**, then watch **Actions**: **Commit Stage** runs, then **Package Stage** builds and pushes an image tagged with the full commit SHA. Wait for Package Stage to finish before the next step, or the tag won't exist yet.

   ```bash
   git add src/main/java
   git commit -m "Update greeting for GitOps demo"
   git push
   ```

3. **Find the image tag in GHCR yourself.** On GitHub, open your repository and click **Packages** in the right-hand sidebar (or go to `https://github.com/orgs/COMP09034/packages`). Open the package, then look at **Recent tagged image versions**. You'll see each image with two tags: `latest` and a 40-character commit SHA. The newest SHA is the image built from your greeting commit. Copy it.

   Confirm it's the right one by checking that it matches the commit SHA shown under the **Commits** tab of the repository (or in the Package Stage run in **Actions**). Don't use `latest`.

4. **Edit the manifest by hand.** Open `k8s/deployment.yaml` and replace `latest` on the `image:` line with the SHA you copied:

   ```yaml
   image: ghcr.io/<ORG>/<REPO>:<PASTE_FULL_SHA_HERE>
   ```

   Then commit and push. (This push triggers the pipeline once more, which builds an image that isn't deployed. That's expected.)

   ```bash
   git add k8s/deployment.yaml
   git commit -m "Update image tag to <SHA>"
   git push
   ```

5. **Watch ArgoCD deploy** (it polls Git every ~3 minutes; click **Refresh** to speed it up). The app goes OutOfSync → Syncing → Synced, and new pods replace old ones:

   ```bash
   kubectl get pods -n catalog -w
   ```

6. **Verify** (restart the port-forward if needed):

   ```bash
   curl http://localhost:9001/
   # Welcome to the Catalog Service - GitOps Edition
   ```

## 3.10 The Complete Pipeline

```text
Developer ── git push ──► GitHub Repository (code + k8s/ manifests)
                               │
                               ▼
                    GitHub Actions (CI)
                    • Build, test, vulnerability scan
                    • Build image, tag with SHA, push to GHCR
                               │
                               ▼
                    GHCR  ◄── pulls image ──┐
                                            │
                    ArgoCD (in cluster) ────┘
                    • Watches k8s/ in Git
                    • Syncs differences, self-heals
                               │
                               ▼
                    Kubernetes: Deployment, Pods, Service
```

**Separation of concerns:** GitHub Actions builds, tests and packages; ArgoCD deploys; Git is the source of truth for both code and infrastructure.

Benefits: full audit trail (every deployment is a commit), easy rollback (`git revert`), disaster recovery from Git, and no cluster credentials stored in CI.

## 3.11 Useful Commands and Troubleshooting

Requires the optional [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/) (`argocd login localhost:8080 --username admin --insecure`).

```bash
argocd app get catalog-service --refresh   # force a Git check
argocd app diff catalog-service            # Git vs cluster
argocd app history catalog-service
git revert HEAD && git push                # roll back via Git (preferred)
```

| Problem | Check |
| ------- | ----- |
| Pods in `ImagePullBackOff` | `kubectl describe pod -n catalog POD_NAME`; confirm the tag exists in GHCR and the package is public or the pull secret is set |
| App stuck OutOfSync | `argocd app diff catalog-service`; `argocd app sync catalog-service --force` |
| Change not detected | Refresh in the UI, or check `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server` |
| App Degraded | `kubectl rollout status deployment/catalog-service -n catalog` |

## 3.12 Clean Up

```bash
kubectl delete -f argocd-application.yaml
kubectl delete namespace catalog
kubectl delete namespace argocd    # optional: uninstall ArgoCD
```

## Conclusion

You built a complete pipeline: commits are built, tested and scanned; successful builds on `main` become immutable, traceable container images; and ArgoCD deploys them to Kubernetes with Git as the single source of truth.

---

[← Previous: Part 2 - The Package Stage](./Part2.md) | [Back to README](./README.md)
