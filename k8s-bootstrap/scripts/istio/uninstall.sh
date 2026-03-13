#!/usr/bin/env bash
set -euo pipefail

# Istio 제거
# Usage: ./scripts/istio/uninstall.sh

echo "=== Istio Uninstall ==="
echo "WARNING: This will remove Istio and all Istio resources."
read -rp "Continue? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
  echo "Aborted."
  exit 0
fi

istioctl uninstall --purge -y
kubectl delete namespace istio-system --ignore-not-found

# namespace label 제거
kubectl label namespace staging istio-injection- 2>/dev/null || true
kubectl label namespace dev istio-injection- 2>/dev/null || true

echo "Istio removed."
