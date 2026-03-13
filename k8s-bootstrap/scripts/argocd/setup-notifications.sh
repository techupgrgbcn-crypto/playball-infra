#!/usr/bin/env bash
set -euo pipefail

# ArgoCD Discord Notifications 설정
# Usage: ./scripts/argocd/setup-notifications.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== ArgoCD Notifications Setup ==="

# 1. Discord ExternalSecret 적용
echo ""
echo "Applying Discord webhook ExternalSecret..."
kubectl apply -f "$REPO_ROOT/argo-init/external-secret-discord.yaml"

# 2. Secret 생성 대기
echo "Waiting for argocd-notifications-secret..."
for i in {1..30}; do
  if kubectl get secret argocd-notifications-secret -n argocd &>/dev/null; then
    url=$(kubectl get secret argocd-notifications-secret -n argocd -o jsonpath='{.data.discord-webhook-url}' 2>/dev/null || echo "")
    if [[ -n "$url" ]]; then
      echo "  Discord webhook secret ready"
      break
    fi
  fi
  es_status=$(kubectl get externalsecret argocd-notifications-secret -n argocd -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null || echo "")
  echo "  Waiting for secret... ($i/30) [ES status: $es_status]"
  sleep 2
done

# Secret 확인
if ! kubectl get secret argocd-notifications-secret -n argocd &>/dev/null; then
  echo ""
  echo "ERROR: argocd-notifications-secret not created!"
  echo ""
  echo "Check AWS Secrets Manager:"
  echo "  aws secretsmanager get-secret-value --secret-id dev/argocd/discord-webhook"
  exit 1
fi

# 3. Notifications ConfigMap 적용
echo ""
echo "Applying Notifications ConfigMap..."
kubectl apply -f "$REPO_ROOT/argo-init/argocd-notifications-cm.yaml"

# 4. ArgoCD Notifications Controller 재시작 (설정 반영)
echo ""
echo "Restarting ArgoCD Notifications Controller..."
kubectl rollout restart deployment argocd-notifications-controller -n argocd 2>/dev/null || \
  echo "  (notifications-controller not found - may need to enable in Helm values)"

echo ""
echo "=== ArgoCD Notifications Setup Complete ==="
echo ""
echo "Test notification:"
echo "  kubectl exec -it deploy/argocd-notifications-controller -n argocd -- \\"
echo "    argocd-notifications template notify app-deployed <APP_NAME> --recipient discord"
echo ""
