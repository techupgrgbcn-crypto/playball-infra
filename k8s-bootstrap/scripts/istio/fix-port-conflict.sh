#!/usr/bin/env bash
set -euo pipefail

# k3s에서 istio-ingressgateway 포트 충돌 해결
# Usage: ./scripts/istio/fix-port-conflict.sh
#
# 문제: 다른 프로세스(python, nginx 등)가 80/443 점유 시
#       k3s svclb가 바인딩 실패함

echo "=== Istio IngressGateway Port Conflict Fix ==="

for port in 80 443; do
  pid=$(sudo ss -tlnp "sport = :${port}" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -1 || true)

  if [[ -z "$pid" ]]; then
    echo "Port ${port}: FREE"
    continue
  fi

  proc_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
  proc_cmd=$(ps -p "$pid" -o args= 2>/dev/null || echo "unknown")

  # svclb는 정상
  if [[ "$proc_name" == "lb-port-"* ]]; then
    echo "Port ${port}: OK (k3s svclb)"
    continue
  fi

  echo "Port ${port}: CONFLICT"
  echo "  Process: ${proc_name} (PID: ${pid})"
  echo "  Command: ${proc_cmd}"
  echo "  Killing..."
  sudo kill -9 "$pid" 2>/dev/null || true
done

# svclb pod 재시작
echo ""
echo "Restarting svclb pods..."
kubectl delete pod -n kube-system \
  -l svccontroller.k3s.cattle.io/svcname=istio-ingressgateway \
  --wait=false 2>/dev/null || true

sleep 5

# 결과 확인
echo ""
echo "=== Result ==="
echo "svclb pods:"
kubectl get pods -n kube-system -l svccontroller.k3s.cattle.io/svcname=istio-ingressgateway -o wide 2>/dev/null || echo "  (not found)"

echo ""
echo "Port bindings:"
sudo ss -tlnp | grep -E ':80|:443' || echo "  (none)"

echo ""
echo "Done."
