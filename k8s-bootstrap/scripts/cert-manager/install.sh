#!/usr/bin/env bash
set -euo pipefail

# cert-manager 설치 (공식 Helm chart)
# Usage: ./scripts/cert-manager/install.sh

NAMESPACE="cert-manager"

echo "=== cert-manager Install ==="

# helm repo 추가
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update

# cert-manager 설치 (CRDs 포함, control-plane 노드에 배치)
helm upgrade --install cert-manager jetstack/cert-manager \
  -n "$NAMESPACE" \
  --create-namespace \
  --set crds.enabled=true \
  --set nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set webhook.nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set cainjector.nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set startupapicheck.nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set tolerations[0].key="node-role.kubernetes.io/control-plane" \
  --set tolerations[0].operator="Exists" \
  --set tolerations[0].effect="NoSchedule" \
  --set webhook.tolerations[0].key="node-role.kubernetes.io/control-plane" \
  --set webhook.tolerations[0].operator="Exists" \
  --set webhook.tolerations[0].effect="NoSchedule" \
  --set cainjector.tolerations[0].key="node-role.kubernetes.io/control-plane" \
  --set cainjector.tolerations[0].operator="Exists" \
  --set cainjector.tolerations[0].effect="NoSchedule" \
  --set startupapicheck.tolerations[0].key="node-role.kubernetes.io/control-plane" \
  --set startupapicheck.tolerations[0].operator="Exists" \
  --set startupapicheck.tolerations[0].effect="NoSchedule" \
  --wait --timeout=5m

echo ""
echo "cert-manager installed."
echo "ClusterIssuer/Certificate는 ArgoCD가 helm repo에서 배포합니다."
