#!/usr/bin/env bash
set -euo pipefail

# Local Path Provisioner 설치
# kubeadm 클러스터용 기본 StorageClass 제공
# Usage: ./scripts/storage/install.sh

LOCAL_PATH_VERSION="${LOCAL_PATH_VERSION:-v0.0.26}"

echo "=== Installing Local Path Provisioner ==="

# Rancher local-path-provisioner 설치
kubectl apply -f "https://raw.githubusercontent.com/rancher/local-path-provisioner/${LOCAL_PATH_VERSION}/deploy/local-path-storage.yaml"

# CP 노드에 배치 (nodeSelector + tolerations)
echo "Patching deployment for control-plane node..."
kubectl patch deployment local-path-provisioner -n local-path-storage --type=json -p='[
  {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"node-role.kubernetes.io/control-plane": ""}},
  {"op": "add", "path": "/spec/template/spec/tolerations", "value": [{"key": "node-role.kubernetes.io/control-plane", "operator": "Exists", "effect": "NoSchedule"}]}
]'

echo "Waiting for local-path-provisioner deployment..."
kubectl wait --for=condition=available deployment/local-path-provisioner -n local-path-storage --timeout=60s

# 기본 StorageClass로 설정
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo ""
echo "=== Local Path Provisioner Installed ==="
kubectl get storageclass
