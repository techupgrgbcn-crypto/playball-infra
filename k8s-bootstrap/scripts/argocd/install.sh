#!/usr/bin/env bash
set -euo pipefail

# ArgoCD 설치 (공식 Helm chart)
# Usage: ./scripts/argocd/install.sh

NAMESPACE="argocd"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== ArgoCD Install ==="

# GitHub Webhook Secret 가져오기 (AWS Secrets Manager에서)
WEBHOOK_SECRET=""
if command -v aws &>/dev/null; then
  WEBHOOK_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id dev/argocd/webhook-github \
    --query 'SecretString' --output text 2>/dev/null || echo "")
fi

if [[ -z "$WEBHOOK_SECRET" ]]; then
  echo "NOTE: GitHub webhook secret not found in AWS SM (dev/argocd/webhook-github)"
  echo "      Webhook will not be configured. To enable:"
  echo "      1. Generate: openssl rand -hex 20"
  echo "      2. Store: aws secretsmanager create-secret --name dev/argocd/webhook-github --secret-string '<secret>'"
  echo ""
fi

# 기존 ArgoCD CRD가 terminating 상태면 완전히 삭제될 때까지 대기
if kubectl get crd applications.argoproj.io &>/dev/null; then
  status=$(kubectl get crd applications.argoproj.io -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null || echo "")
  if [[ -n "$status" ]]; then
    echo "ArgoCD CRDs are terminating, waiting for deletion..."
    for i in {1..30}; do
      if ! kubectl get crd applications.argoproj.io &>/dev/null; then
        echo "  CRDs deleted"
        break
      fi
      echo "  Waiting... ($i/30)"
      # finalizer 제거 시도
      kubectl patch crd applications.argoproj.io -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
      sleep 2
    done
  fi
fi

# namespace 먼저 생성 (--create-namespace 버그 대응)
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# helm repo 추가
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

# ArgoCD 설치
# --insecure: ArgoCD 자체 TLS 비활성화
# 이유: Istio Gateway에서 TLS 종료 후 HTTP로 ArgoCD에 연결
# 구조: Client → HTTPS → Istio Gateway → HTTP → ArgoCD
# CP 노드에 배치 (nodeSelector + tolerations)
# ArgoCD 도메인 설정
ARGOCD_URL="${ARGOCD_URL:-https://argocd.goormgb.space}"

# Helm install with optional webhook secret
HELM_ARGS=(
  upgrade --install argocd argo/argo-cd
  -n "$NAMESPACE"
  --create-namespace
  --set 'server.extraArgs={--insecure}'
  --set "configs.cm.url=$ARGOCD_URL"
  --set global.nodeSelector."node-role\.kubernetes\.io/control-plane"=""
  --set global.tolerations[0].key="node-role.kubernetes.io/control-plane"
  --set global.tolerations[0].operator="Exists"
  --set global.tolerations[0].effect="NoSchedule"
)

# Webhook secret 설정 (있는 경우만)
if [[ -n "$WEBHOOK_SECRET" ]]; then
  echo "GitHub webhook secret found, configuring..."
  HELM_ARGS+=(--set "configs.secret.extra.webhook\.github\.secret=$WEBHOOK_SECRET")
fi

helm "${HELM_ARGS[@]}" --wait --timeout=5m

# Calico 리소스 health check 설정 (Helm --set으로 Lua 스크립트 전달 시 특수문자 문제 발생)
echo "Applying Calico health checks to argocd-cm..."
kubectl patch cm argocd-cm -n argocd --type merge -p '{
  "data": {
    "resource.customizations.health.operator.tigera.io_Installation": "hs = {}\nif obj.status ~= nil and obj.status.conditions ~= nil then\n  for i, c in ipairs(obj.status.conditions) do\n    if c.type == \"Ready\" and c.status == \"True\" then\n      hs.status = \"Healthy\"\n      return hs\n    end\n  end\nend\nhs.status = \"Progressing\"\nreturn hs",
    "resource.customizations.health.operator.tigera.io_APIServer": "hs = {}\nif obj.status ~= nil and obj.status.conditions ~= nil then\n  for i, c in ipairs(obj.status.conditions) do\n    if c.type == \"Ready\" and c.status == \"True\" then\n      hs.status = \"Healthy\"\n      return hs\n    end\n  end\nend\nhs.status = \"Progressing\"\nreturn hs"
  }
}'

# ArgoCD server 재시작 (ConfigMap 변경 반영)
kubectl rollout restart deploy/argocd-server -n argocd
kubectl rollout status deploy/argocd-server -n argocd --timeout=60s

# ArgoCD CRD가 ready인지 확인
echo "Waiting for ArgoCD CRDs to be ready..."
for i in {1..30}; do
  if kubectl get crd applications.argoproj.io &>/dev/null; then
    echo "  ArgoCD CRDs ready"
    break
  fi
  echo "  Waiting for CRDs... ($i/30)"
  sleep 2
done

# Application CRD가 실제로 사용 가능한지 확인
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=60s 2>/dev/null || true

# GitHub SSH Key ExternalSecret 적용 및 Secret 생성 대기
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo ""
echo "=== Setting up GitHub SSH Key ==="

# 1. ESO가 준비될 때까지 대기
echo "Checking ESO readiness..."
for i in {1..30}; do
  if kubectl get deployment -n external-secrets external-secrets -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -q "1"; then
    echo "  ESO is ready"
    break
  fi
  echo "  Waiting for ESO... ($i/30)"
  sleep 2
done

# 2. ClusterSecretStore가 Valid 상태인지 확인
echo "Checking ClusterSecretStore..."
for i in {1..30}; do
  status=$(kubectl get clustersecretstore aws-secrets-manager -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [[ "$status" == "True" ]]; then
    echo "  ClusterSecretStore is ready"
    break
  fi
  echo "  Waiting for ClusterSecretStore... ($i/30)"
  sleep 2
done

# 3. ExternalSecret 삭제 후 재적용 (stale 상태 방지)
echo "Applying ExternalSecret..."
kubectl delete externalsecret repo-goormgb-helm -n argocd 2>/dev/null || true
sleep 2
if ! kubectl apply -f "$REPO_ROOT/argo-init/external-secret-github.yaml"; then
  echo "ERROR: Failed to apply ExternalSecret"
  exit 1
fi
sleep 3

# 4. Secret이 생성될 때까지 대기 (최대 60초)
echo "Waiting for repo-goormgb-helm secret..."
for i in {1..30}; do
  if kubectl get secret repo-goormgb-helm -n argocd &>/dev/null; then
    # secret 내용 확인
    if kubectl get secret repo-goormgb-helm -n argocd -o jsonpath='{.data.sshPrivateKey}' 2>/dev/null | grep -q "."; then
      echo "  GitHub SSH secret ready"
      break
    fi
  fi
  # ExternalSecret 상태 확인
  es_status=$(kubectl get externalsecret repo-goormgb-helm -n argocd -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null || echo "")
  echo "  Waiting for secret... ($i/30) [ES status: $es_status]"
  sleep 2
done

# Secret 생성 확인
if ! kubectl get secret repo-goormgb-helm -n argocd &>/dev/null; then
  echo ""
  echo "ERROR: repo-goormgb-helm secret not created!"
  echo ""
  echo "Debug:"
  kubectl get clustersecretstore aws-secrets-manager -o yaml 2>/dev/null | grep -A5 "status:" || true
  kubectl get externalsecret repo-goormgb-helm -n argocd -o yaml 2>/dev/null | grep -A10 "status:" || true
  echo ""
  echo "Possible causes:"
  echo "  1. AWS credentials not set: make bootstrap-aws"
  echo "  2. Secret not in AWS SM: aws secretsmanager get-secret-value --secret-id dev/argocd/github-ssh"
  exit 1
fi

echo ""
echo "=== Applying RBAC from ESO ==="

# ESO RBAC Secret이 생성될 때까지 대기
echo "Waiting for argocd-rbac-eso secret..."
for i in {1..30}; do
  if kubectl get secret argocd-rbac-eso -n argocd &>/dev/null; then
    policy=$(kubectl get secret argocd-rbac-eso -n argocd -o jsonpath='{.data.policy_csv}' 2>/dev/null | base64 -d || echo "")
    if [[ -n "$policy" ]]; then
      echo "  RBAC secret ready"
      # ConfigMap 생성 또는 업데이트 (patch는 기존 리소스 필요, apply는 없으면 생성)
      kubectl create configmap argocd-rbac-cm -n argocd \
        --from-literal="policy.csv=$policy" \
        --from-literal="policy.default=role:none" \
        --from-literal="scopes=[email]" \
        --dry-run=client -o yaml | kubectl apply -f -
      echo "  RBAC ConfigMap applied"
      break
    fi
  fi
  echo "  Waiting for RBAC secret... ($i/30)"
  sleep 2
done

echo ""
echo "=== ArgoCD Installed ==="
echo ""
echo "Initial admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""

# Webhook 설정 안내
if [[ -n "$WEBHOOK_SECRET" ]]; then
  echo "GitHub Webhook configured!"
  echo "  Add webhook in GitHub repo settings:"
  echo "  - URL: https://argocd.goormgb.space/api/webhook"
  echo "  - Content-Type: application/json"
  echo "  - Secret: (stored in AWS SM: dev/argocd/webhook-github)"
  echo "  - Events: Just the push event"
else
  echo "GitHub Webhook not configured."
  echo "  To enable, store secret in AWS SM and re-run install:"
  echo "  aws secretsmanager create-secret --name dev/argocd/webhook-github --secret-string \"\$(openssl rand -hex 20)\""
fi
