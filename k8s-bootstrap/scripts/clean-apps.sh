#!/usr/bin/env bash
set -euo pipefail

# 앱/인프라 정리 (ArgoCD, cert-manager 유지)
# Usage: ./scripts/clean-apps.sh

# ArgoCD, cert-manager는 유지 (UI 접근, TLS 발급 제한)
NAMESPACES="dev-app dev data external-secrets istio-system istio-ingress monitoring staging calico-system calico-apiserver tigera-operator local-path-storage"

# TLS Secret 백업 경로
TLS_BACKUP="/tmp/myproject-tls-backup.yaml"

echo "=== Clean Apps ==="
echo ""
echo "This will REMOVE:"
echo "  - All ArgoCD Applications (ArgoCD itself preserved)"
echo "  - All Helm releases"
echo "  - App namespaces (cert-manager preserved)"
echo "  - Istio, Calico, ESO, CRDs"
echo ""
echo "ArgoCD, cert-manager, TLS secrets will be preserved."
echo ""
read -rp "Are you sure? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "=== Step 0: Backup TLS secrets ==="
# istio-system의 TLS secret 백업 (Let's Encrypt 재발급 방지)
if kubectl get secret myproject-tls -n istio-system &>/dev/null; then
  echo "  Backing up myproject-tls secret..."
  kubectl get secret myproject-tls -n istio-system -o json | \
    jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.namespace, .metadata.managedFields, .metadata.ownerReferences)' \
    > "$TLS_BACKUP"
  echo "  Saved to $TLS_BACKUP"
else
  echo "  No TLS secret found, skipping backup"
fi

echo ""
echo "=== Step 1: Delete ArgoCD apps (cert-manager 제외, finalizer 제거 후 삭제) ==="
# cert-manager 관련 앱은 보존
PRESERVE_APPS="cert-manager cert-manager-config"

# Finalizer 제거 및 삭제 (보존 앱 제외)
for app in $(kubectl get applications.argoproj.io -n argocd -o name 2>/dev/null || true); do
  appname=$(echo "$app" | sed 's|application.argoproj.io/||')
  if echo "$PRESERVE_APPS" | grep -qw "$appname"; then
    echo "  Preserving $appname"
    continue
  fi
  kubectl patch "$app" -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$app" -n argocd --force --grace-period=0 --wait=false 2>/dev/null || true
done

# ApplicationSet 삭제
for appset in $(kubectl get applicationsets.argoproj.io -n argocd -o name 2>/dev/null || true); do
  kubectl patch "$appset" -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$appset" -n argocd --force --grace-period=0 --wait=false 2>/dev/null || true
done

# 삭제 대기 (cert-manager 제외하고 카운트)
echo "  Waiting for apps to be deleted..."
for i in {1..15}; do
  remaining=$(kubectl get applications.argoproj.io -n argocd --no-headers 2>/dev/null | grep -cvE "cert-manager" 2>/dev/null) || remaining=0
  if [[ "$remaining" -eq 0 ]]; then
    echo "  All target ArgoCD apps deleted"
    break
  fi
  echo "  Remaining: $remaining apps ($i/15)"
  # 남은 앱 finalizer 재시도 (보존 앱 제외)
  for app in $(kubectl get applications.argoproj.io -n argocd -o name 2>/dev/null | grep -vE "cert-manager" || true); do
    kubectl patch "$app" -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    kubectl delete "$app" -n argocd --force --grace-period=0 --wait=false 2>/dev/null || true
  done
  sleep 2
done

echo ""
echo "=== Step 2: Uninstall Helm releases (cert-manager, ArgoCD 제외) ==="
# cert-manager, argocd namespace의 helm release는 유지
for release in $(helm list -A -q 2>/dev/null || true); do
  ns=$(helm list -A --filter "^${release}$" -o json 2>/dev/null | jq -r ".[0].namespace // empty")
  if [[ -n "$ns" && "$ns" != "cert-manager" && "$ns" != "argocd" ]]; then
    echo "  Uninstalling $release from $ns"
    helm uninstall "$release" -n "$ns" --no-hooks --wait=false 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 3: Stop controllers (ArgoCD, cert-manager 유지) ==="
# ArgoCD, cert-manager는 유지하고 다른 컨트롤러만 중지
kubectl scale deployment -n external-secrets --all --replicas=0 2>/dev/null || true
kubectl scale deployment -n tigera-operator --all --replicas=0 2>/dev/null || true
sleep 2

echo ""
echo "=== Step 4: Istio uninstall ==="
ISTIOCTL=""
if command -v istioctl &>/dev/null; then
  ISTIOCTL="istioctl"
elif [[ -x "./istio-1.24.2/bin/istioctl" ]]; then
  ISTIOCTL="./istio-1.24.2/bin/istioctl"
fi
if [[ -n "$ISTIOCTL" ]]; then
  echo "  Using $ISTIOCTL"
  $ISTIOCTL uninstall --purge -y 2>/dev/null || true
fi

echo ""
echo "=== Step 5: Delete Calico resources ==="

# Tigera Operator 먼저 중지 (리소스 재생성 방지)
kubectl scale deployment -n tigera-operator --all --replicas=0 2>/dev/null || true

# Calico namespace 내 리소스 먼저 삭제
for ns in calico-system calico-apiserver; do
  kubectl delete deploy,ds,sts,rs,job --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
  kubectl delete pods --all -n "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
done

# IPPool 삭제
for pool in $(kubectl get ippool -o name 2>/dev/null || true); do
  kubectl patch "$pool" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  kubectl delete "$pool" --force --grace-period=0 --wait=false 2>/dev/null || true
done

# Installation/APIServer CR 삭제 (finalizer를 빈 배열로)
kubectl patch installation default -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
kubectl delete installation default --force --grace-period=0 --wait=false 2>/dev/null || true
kubectl patch apiserver default -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
kubectl delete apiserver default --force --grace-period=0 --wait=false 2>/dev/null || true

# 삭제 완료 대기 (최대 20초)
echo "  Waiting for Calico CRs to be deleted..."
for i in {1..10}; do
  if ! kubectl get installation default &>/dev/null && ! kubectl get apiserver default &>/dev/null; then
    echo "  Calico CRs deleted"
    break
  fi
  kubectl patch installation default -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  kubectl patch apiserver default -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  sleep 2
done

# tigera-operator namespace 정리
kubectl delete deploy,ds,sts,rs,job --all -n tigera-operator --force --grace-period=0 --wait=false 2>/dev/null || true
kubectl delete pods --all -n tigera-operator --force --grace-period=0 --wait=false 2>/dev/null || true

echo ""
echo "=== Step 6: Delete namespaces and force finalize ==="
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  Processing $ns..."
    # 1. 삭제 명령 (비동기)
    kubectl delete ns "$ns" --force --grace-period=0 --wait=false 2>/dev/null || true
    # 2. 바로 Finalizer 제거 API 호출
    kubectl get ns "$ns" -o json 2>/dev/null | \
      jq '.spec.finalizers = null' | \
      kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
  fi
done

echo ""
echo "=== Step 7: Delete CRDs (cert-manager, ArgoCD 보존) ==="
# CRD finalizer 제거 후 삭제 (cert-manager, argoproj 제외)
for crd in $(kubectl get crd -o name 2>/dev/null | grep -E "istio|tigera|calico|projectcalico|external-secrets"); do
  kubectl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$crd" --wait=false 2>/dev/null || true
done

# CRD가 완전히 삭제될 때까지 대기 (최대 30초)
echo "  Waiting for CRDs to be deleted..."
for i in {1..15}; do
  if ! kubectl get crd -o name 2>/dev/null | grep -qE "istio|tigera|calico|projectcalico|external-secrets"; then
    echo "  All target CRDs deleted"
    break
  fi
  echo "  Waiting... ($i/15)"
  # 남은 CRD finalizer 제거 재시도
  for crd in $(kubectl get crd -o name 2>/dev/null | grep -E "istio|tigera|calico|projectcalico|external-secrets" 2>/dev/null || true); do
    kubectl patch "$crd" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  done
  sleep 2
done

echo ""
echo "=== Step 8: Force delete orphan pods ==="
for ns in $NAMESPACES; do
  kubectl delete pods --all -n "$ns" --force --grace-period=0 2>/dev/null || true
done

echo ""
echo "=== Step 9: Final verification ==="
sleep 2
REMAINING=""
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    REMAINING="$REMAINING $ns"
  fi
done

if [[ -n "$REMAINING" ]]; then
  echo "  Remaining namespaces:$REMAINING"
  echo "  Retrying finalize..."
  for ns in $REMAINING; do
    kubectl get ns "$ns" -o json 2>/dev/null | \
      jq '.spec.finalizers = null' | \
      kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
  done
  sleep 2
fi

# 최종 확인
FAILED=0
for ns in $NAMESPACES; do
  if kubectl get ns "$ns" &>/dev/null; then
    echo "  $ns still exists"
    FAILED=1
  fi
done

if [[ $FAILED -eq 0 ]]; then
  echo "  All namespaces cleaned"
fi

echo ""
echo "=== Clean complete ==="
echo ""
echo "Next: make install-all"
