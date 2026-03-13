#!/usr/bin/env bash
set -euo pipefail

# 컨트롤 플레인 컴포넌트 메트릭을 외부에서 접근 가능하도록 설정
# kubeadm 기본 설정은 127.0.0.1에서만 리슨함

echo "=== Enabling control plane metrics on 0.0.0.0 ==="

# kube-scheduler
SCHEDULER_MANIFEST="/etc/kubernetes/manifests/kube-scheduler.yaml"
if [[ -f "$SCHEDULER_MANIFEST" ]]; then
  if grep -q "bind-address=127.0.0.1" "$SCHEDULER_MANIFEST"; then
    echo "  Updating kube-scheduler..."
    sudo sed -i 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/' "$SCHEDULER_MANIFEST"
  else
    echo "  kube-scheduler already configured or using default"
  fi
fi

# kube-controller-manager
CONTROLLER_MANIFEST="/etc/kubernetes/manifests/kube-controller-manager.yaml"
if [[ -f "$CONTROLLER_MANIFEST" ]]; then
  if grep -q "bind-address=127.0.0.1" "$CONTROLLER_MANIFEST"; then
    echo "  Updating kube-controller-manager..."
    sudo sed -i 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/' "$CONTROLLER_MANIFEST"
  else
    echo "  kube-controller-manager already configured or using default"
  fi
fi

# kube-proxy (ConfigMap 수정)
echo "  Updating kube-proxy ConfigMap..."
kubectl get cm kube-proxy -n kube-system -o yaml | \
  sed 's/metricsBindAddress: ""/metricsBindAddress: "0.0.0.0:10249"/' | \
  sed 's/metricsBindAddress: 127.0.0.1:10249/metricsBindAddress: 0.0.0.0:10249/' | \
  kubectl apply -f -

# kube-proxy 재시작
echo "  Restarting kube-proxy..."
kubectl rollout restart daemonset kube-proxy -n kube-system

echo ""
echo "  Waiting for components to restart..."
sleep 15

# 확인
echo ""
echo "=== Checking metrics ports ==="
echo "  Scheduler (10259):"
sudo ss -tlnp | grep 10259 || echo "    Not yet listening"
echo "  Controller Manager (10257):"
sudo ss -tlnp | grep 10257 || echo "    Not yet listening"
echo "  Proxy (10249):"
sudo ss -tlnp | grep 10249 || echo "    Not yet listening"

echo ""
echo "=== Creating Endpoints for Prometheus ==="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/scheduler-endpoints.yaml"
kubectl apply -f "$SCRIPT_DIR/controller-manager-endpoints.yaml"
echo "  Endpoints created"

echo ""
echo "=== Done ==="
echo "Note: kube-scheduler and kube-controller-manager may take ~30 seconds to restart"
