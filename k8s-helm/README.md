# Kubernetes Helm Charts

> GitOps configuration with ArgoCD App of Apps pattern

## Structure

```
k8s-helm/
├── common-charts/          # Reusable Helm charts
│   ├── apps/
│   │   ├── java-service/   # Spring Boot microservice template
│   │   └── ai-service/     # Python AI service template
│   └── infra/
│       ├── istio/          # Istio configurations
│       ├── monitoring/     # Prometheus, Grafana, Loki
│       └── argocd/         # ArgoCD configurations
│
├── staging/                # Staging environment
│   ├── root/               # App of Apps root application
│   │   └── values.yaml     # All applications defined here
│   └── values/             # Environment-specific values
│
└── prod/                   # Production environment
```

## App of Apps Pattern

```yaml
# staging/root/values.yaml
ociCharts:
  istio-base:
    enabled: true
    version: "1.29.1"
  kube-prometheus-stack:
    enabled: true
    version: "82.10.3"

gitCharts:
  namespaces:
    enabled: true
  istio-gateway:
    enabled: true
```

## Deployment

ArgoCD automatically syncs from Git:

```bash
# Check sync status
kubectl get applications -n argocd

# Manual sync
argocd app sync staging-root
```
