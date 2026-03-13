#!/usr/bin/env bash
set -euo pipefail

# External Secrets Operator 설치 (공식 Helm chart)
# Usage: ./scripts/eso/install.sh

NAMESPACE="external-secrets"

echo "=== External Secrets Operator Install ==="

# 기존 ESO CRD가 terminating 상태면 강제 삭제
if kubectl get crd externalsecrets.external-secrets.io &>/dev/null; then
  status=$(kubectl get crd externalsecrets.external-secrets.io -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null || echo "")
  if [[ -n "$status" ]]; then
    echo "ESO CRDs are terminating, forcing deletion..."
    for crd in $(kubectl get crd -o name 2>/dev/null | grep "external-secrets" 2>/dev/null || true); do
      kubectl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
      kubectl delete "$crd" --force --grace-period=0 --wait=false 2>/dev/null || true
    done
    # namespace 정리
    if kubectl get ns external-secrets &>/dev/null; then
      kubectl delete ns external-secrets --force --grace-period=0 --wait=false 2>/dev/null || true
      kubectl get ns external-secrets -o json 2>/dev/null | jq '.spec.finalizers = null' | \
        kubectl replace --raw "/api/v1/namespaces/external-secrets/finalize" -f - 2>/dev/null || true
    fi
    # 삭제 완료 대기
    for i in {1..15}; do
      if ! kubectl get crd externalsecrets.external-secrets.io &>/dev/null; then
        echo "  CRDs deleted"
        break
      fi
      echo "  Waiting... ($i/15)"
      for crd in $(kubectl get crd -o name 2>/dev/null | grep "external-secrets" 2>/dev/null || true); do
        kubectl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
      done
      sleep 2
    done
  fi
fi

# helm repo 추가
helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm repo update

# namespace 생성
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ESO 설치 (control-plane 노드에 배치)
helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  -n "$NAMESPACE" \
  --set installCRDs=true \
  --set nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set webhook.nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set certController.nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set tolerations[0].key="node-role.kubernetes.io/control-plane" \
  --set tolerations[0].operator="Exists" \
  --set tolerations[0].effect="NoSchedule" \
  --set webhook.tolerations[0].key="node-role.kubernetes.io/control-plane" \
  --set webhook.tolerations[0].operator="Exists" \
  --set webhook.tolerations[0].effect="NoSchedule" \
  --set certController.tolerations[0].key="node-role.kubernetes.io/control-plane" \
  --set certController.tolerations[0].operator="Exists" \
  --set certController.tolerations[0].effect="NoSchedule" \
  --wait --timeout=5m

# CRD 등록 대기
echo "Waiting for CRDs to be registered..."
kubectl wait --for condition=established --timeout=60s \
  crd/clustersecretstores.external-secrets.io \
  crd/externalsecrets.external-secrets.io

echo ""
echo "ESO installed. Next steps:"
echo "  1. ./scripts/eso/bootstrap-aws.sh  (AWS 자격증명 등록)"
echo "  2. ArgoCD가 ClusterSecretStore를 helm repo에서 배포합니다."
