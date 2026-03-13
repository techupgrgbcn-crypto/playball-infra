#!/usr/bin/env bash
set -euo pipefail

# etcd 메트릭을 외부 IP에서 접근 가능하도록 설정
# kubeadm 기본 설정은 127.0.0.1:2381에서만 리슨함

ETCD_MANIFEST="/etc/kubernetes/manifests/etcd.yaml"
CP_IP=$(hostname -I | awk '{print $1}')

echo "=== Enabling etcd metrics on external IP ==="
echo "  Control Plane IP: $CP_IP"

if [[ ! -f "$ETCD_MANIFEST" ]]; then
  echo "ERROR: etcd manifest not found at $ETCD_MANIFEST"
  echo "This script must be run on the control-plane node."
  exit 1
fi

# 이미 외부 IP가 설정되어 있는지 확인
if grep -q "listen-metrics-urls=.*${CP_IP}" "$ETCD_MANIFEST"; then
  echo "  etcd metrics already configured for external IP"
else
  echo "  Updating etcd manifest..."
  sudo sed -i "s|--listen-metrics-urls=http://127.0.0.1:2381|--listen-metrics-urls=http://127.0.0.1:2381,http://${CP_IP}:2381|" "$ETCD_MANIFEST"

  echo "  Waiting for etcd to restart..."
  sleep 10

  # 확인
  if sudo ss -tlnp | grep -q "${CP_IP}:2381"; then
    echo "  etcd metrics now listening on ${CP_IP}:2381"
  else
    echo "  WARNING: etcd may still be restarting. Check with: sudo ss -tlnp | grep 2381"
  fi
fi

echo ""
echo "=== Done ==="
