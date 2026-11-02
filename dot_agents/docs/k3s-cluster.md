# k3s Cluster — k3s-admin

Repo: `~/Workspace/Misc/k3s-admin`
GitOps: ArgoCD watches this repo → auto-syncs to cluster. **Do not `kubectl apply` manually.**

## Cluster Topology

| Node | IP | Role | Notes |
|------|----|------|-------|
| k3sserver01 | 192.168.2.21 | control-plane, etcd | kernel 6.1 |
| k3sagent01 | 192.168.2.31 | worker | Intel GPU (i915), kernel 6.12 |
| k3sagent02 | 192.168.2.32 | worker | kernel 6.1 |
| k3sagent03 | 192.168.2.33 | worker | kernel 6.1 |
| k3sagent04-2 | 192.168.2.34 | worker | kernel 6.1 |

Version: v1.34.1+k3s1 | Runtime: containerd | OS: Debian 12

## Infrastructure Stack

| Layer | Components |
|-------|-----------|
| GitOps | ArgoCD + argocd-image-updater (semver, write-back to git) |
| Ingress | Traefik (default) + MetalLB (L2, `192.168.2.x` pool) |
| Storage | Piraeus/LINSTOR (replicated DRBD), NFS subdir provisioner, local-path |
| Monitoring | kube-prometheus-stack (Prometheus + Grafana + Alertmanager), Loki + Promtail |
| Backup | Velero + Kopia (per-namespace repo maintenance) |
| Certs | cert-manager + certimate |
| Auth | Keycloak (SSO), Authelia |
| GPU | intel-gpu-plugin + node-feature-discovery |
| Notifications | ntfy + alertmanager-ntfy |

## Repo Structure

Three manifest approaches coexist:

- **Helm charts** (`Chart.yaml`): most services — gitea, jira, keycloak, immich, dify, homepage, etc.
- **Kustomize** (`kustomization.yaml`): certificates, metallb, reflector, storage-classes, monitoring-resources
- **Raw manifests**: secrets (`secrets/`), Grafana dashboards

ArgoCD Applications: `argo-cd/applications/*.yaml` — each points to a directory in this repo.

## Namespaces / Workloads (~45 ns)

Key services: immich, gitea, dify, keycloak, jira, coder, homepage, trilium,
navidrome, audiobookshelf, karakeep, reader, meilisearch, huginn, semaphore,
uptime-kuma, scrutiny, chartdb, drawdb, cyberchef, it-tools, adventure-log,
databasus, certimate, headscale-admin, ntfy

## Common Operations

```bash
# Health check
kubectl get nodes -o wide
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl get events -A --sort-by='.lastTimestamp' | tail -30

# ArgoCD status
kubectl get applications -n argocd -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'

# Deploy / update a service
cd ~/Workspace/Misc/k3s-admin/<service>
# edit values.yaml / manifests
git add -A && git commit -m "update <service>" && git push
# ArgoCD auto-syncs (automated.prune + selfHeal enabled)

# Helm operations (local validation before push)
helm lint <chart-dir>
helm template <release> <chart-dir>
helm dependency update <chart-dir>

# Kustomize
kubectl kustomize <dir>          # preview
kubectl apply -k <dir> --dry-run=client

# Emergency: manual intervention (avoid, breaks GitOps)
kubectl delete pod <pod> -n <ns>   # restart a pod
kubectl rollout restart deploy/<name> -n <ns>
```

## ArgoCD Image Updater Pattern

Applications use annotations for auto image updates:
```yaml
annotations:
  argocd-image-updater.argoproj.io/image-list: alias=image:^constraint
  argocd-image-updater.argoproj.io/update-strategy: semver
  argocd-image-updater.argoproj.io/write-back-method: git
```

## Gotchas

- Pushing to git is the deploy mechanism. Manual `kubectl apply` will be reverted by ArgoCD selfHeal.
- `secrets/` contains base64-encoded K8s Secrets in git — sensitive but not encrypted at rest.
- Intel GPU workloads (immich ML) pin to k3sagent01 via node-feature-discovery labels.
- Piraeus/LINSTOR volumes are replicated; pod rescheduling may take time for volume migration.
- Velero backup annotations: `backup.velero.io/backup: "true"` on workloads that need backup.
- Some charts use TrueCharts common library (`oci://tccr.io/truecharts`).
