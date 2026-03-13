#!/usr/bin/env bash
set -euo pipefail

# Istio 설치 (istioctl 사용)
# Usage: ./scripts/istio/install.sh
#
# kubeadm 클러스터용:
# - externalIPs로 외부 접근 설정 (LoadBalancer 없음)
# - 기본 EXTERNAL_IP=10.0.0.11 (worker-node-1, worker node)

ISTIO_VERSION="${ISTIO_VERSION:-1.24.2}"

# 80/443 포트 충돌 해결 함수
fix_port_conflict() {
  echo "=== Checking port 80/443 conflicts ==="

  local conflicts=false
  for port in 80 443; do
    local pid
    pid=$(sudo ss -tlnp "sport = :${port}" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -1 || true)

    if [[ -n "$pid" ]]; then
      local proc_name
      proc_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")

      # svclb (k3s servicelb)는 정상이므로 스킵
      if [[ "$proc_name" == *"svclb"* ]] || [[ "$proc_name" == "lb-port-"* ]]; then
        echo "Port ${port}: OK (k3s servicelb)"
        continue
      fi

      echo "WARNING: Port ${port} is occupied by ${proc_name} (PID: ${pid})"
      echo "Killing process..."
      sudo kill -9 "$pid" 2>/dev/null || true
      conflicts=true
    fi
  done

  if [[ "$conflicts" == "true" ]]; then
    echo "Port conflicts resolved. Restarting svclb pods..."
    kubectl delete pod -n kube-system -l svccontroller.k3s.cattle.io/svcname=istio-ingressgateway 2>/dev/null || true
    sleep 5
  fi

  echo "Port check complete."
}

echo "=== Istio ${ISTIO_VERSION} Install ==="

# 이미 Istio가 정상 동작 중인지 확인
if kubectl get deploy istiod -n istio-system &>/dev/null; then
  READY=$(kubectl get deploy istiod -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [[ "$READY" -gt 0 ]]; then
    echo "Istio already installed and healthy (istiod ready: $READY)"
    echo "Skipping installation."
    kubectl get pods -n istio-system
    exit 0
  fi
fi

# 기존 Istio 리소스 정리
echo "=== Cleaning up old Istio resources ==="

# istioctl 경로 확인
ISTIOCTL=""
if command -v istioctl &>/dev/null; then
  ISTIOCTL="istioctl"
elif [[ -x "./istio-${ISTIO_VERSION}/bin/istioctl" ]]; then
  ISTIOCTL="./istio-${ISTIO_VERSION}/bin/istioctl"
elif [[ -x "./istio-1.24.2/bin/istioctl" ]]; then
  ISTIOCTL="./istio-1.24.2/bin/istioctl"
fi

if [[ -n "$ISTIOCTL" ]]; then
  echo "Uninstalling existing Istio with $ISTIOCTL..."
  $ISTIOCTL uninstall --purge -y 2>/dev/null || true
fi

# 남은 리소스 강제 삭제
kubectl delete deploy,svc,hpa --all -n istio-system --force --grace-period=0 --wait=false 2>/dev/null || true
kubectl delete deploy,svc --all -n istio-ingress --force --grace-period=0 --wait=false 2>/dev/null || true

# namespace 정리 (istio-ingress만, istio-system은 유지)
if kubectl get ns istio-ingress &>/dev/null; then
  kubectl delete ns istio-ingress --force --grace-period=0 --wait=false 2>/dev/null || true
  kubectl get ns istio-ingress -o json 2>/dev/null | jq '.spec.finalizers = null' | \
    kubectl replace --raw "/api/v1/namespaces/istio-ingress/finalize" -f - 2>/dev/null || true
fi

# Istio CRD 정리 (terminating 상태 처리)
for crd in $(kubectl get crd -o name 2>/dev/null | grep "istio" 2>/dev/null || true); do
  kubectl patch "$crd" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
done

sleep 3

# istioctl 설치 확인
if ! command -v istioctl &>/dev/null; then
  echo "Installing istioctl..."
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -
  export PATH="$PWD/istio-${ISTIO_VERSION}/bin:$PATH"
  echo ""
  echo "NOTE: Add to your PATH permanently:"
  echo "  export PATH=\$PATH:$PWD/istio-${ISTIO_VERSION}/bin"
  echo ""
fi

# pre-check
istioctl x precheck

# Istio 설치 (default profile + externalIPs for kubeadm)
EXTERNAL_IP="${EXTERNAL_IP:-10.0.0.11}"  # worker-node-1 (worker node)

# IstioOperator 매니페스트로 설치 (CLI 플래그 버그 회피)
# istiod → CP 노드, ingressgateway → Worker 노드
cat <<EOF | istioctl install -y -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  components:
    pilot:
      k8s:
        nodeSelector:
          node-role.kubernetes.io/control-plane: ""
        tolerations:
          - key: node-role.kubernetes.io/control-plane
            operator: Exists
            effect: NoSchedule
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
        k8s:
          nodeSelector:
            kubernetes.io/hostname: worker-node-1
          service:
            externalIPs:
              - ${EXTERNAL_IP}
          hpaSpec:
            minReplicas: 1
            maxReplicas: 2
  values:
    gateways:
      istio-ingressgateway:
        serviceAnnotations:
          metallb.universe.tf/allow-shared-ip: default
EOF

echo "IngressGateway externalIP: ${EXTERNAL_IP}"

# namespace label 설정
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

# staging namespace에만 sidecar injection 활성화
kubectl label namespace staging istio-injection=enabled --overwrite 2>/dev/null || true

# dev namespace는 sidecar injection 비활성화
kubectl label namespace dev istio-injection=disabled --overwrite 2>/dev/null || true

# 포트 충돌 확인 (선택사항)
# fix_port_conflict

# TLS Secret 복원 (clean-apps에서 백업한 경우)
TLS_BACKUP="/tmp/goormgb-tls-backup.yaml"
if [[ -f "$TLS_BACKUP" ]]; then
  echo ""
  echo "=== Restoring TLS secret from backup ==="
  if kubectl apply -n istio-system -f "$TLS_BACKUP" 2>/dev/null; then
    echo "TLS secret restored!"
  else
    echo "TLS restore skipped (may need cert-manager to issue new cert)"
  fi
  rm -f "$TLS_BACKUP"
fi

echo ""
echo "=== Istio Install Complete ==="
echo ""
echo "Verify:"
echo "  istioctl verify-install"
echo "  kubectl get pods -n istio-system"
echo "  sudo ss -tlnp | grep -E ':80|:443'  # port binding check"
echo ""
echo "Istio 설정(Gateway, VirtualService)은 ArgoCD가 helm repo에서 배포합니다."
