#!/usr/bin/env bash
set -euo pipefail

# Calico CNI 설치 for kubeadm cluster
# - Tigera Operator 방식
# - VXLAN encapsulation
# - nodeAddressAutodetection: CIDR 기반 (노드별 인터페이스명 달라도 OK)

CALICO_VERSION="${CALICO_VERSION:-v3.29.3}"
POD_CIDR="${POD_CIDR:-10.244.0.0/16}"
NODE_CIDR="${NODE_CIDR:-10.0.0.0/24}"
TIMEOUT="${TIMEOUT:-300}"

echo "=== Installing Calico CNI ==="
echo "  Version: $CALICO_VERSION"
echo "  Pod CIDR: $POD_CIDR"
echo "  Node CIDR: $NODE_CIDR (for IP autodetection)"
echo "  Timeout: ${TIMEOUT}s"
echo ""

# 이미 Calico가 정상 동작 중인지 확인
if kubectl get daemonset -n calico-system calico-node &>/dev/null; then
  READY=$(kubectl get daemonset -n calico-system calico-node -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
  DESIRED=$(kubectl get daemonset -n calico-system calico-node -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
  POD_COUNT=$(kubectl get pods -n calico-system --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$READY" == "$DESIRED" && "$READY" != "0" && "$POD_COUNT" -gt 0 ]]; then
    echo "Calico already installed and healthy ($READY/$DESIRED nodes ready, $POD_COUNT pods)"
    echo "Skipping installation."
    kubectl get pods -n calico-system
    exit 0
  fi
fi

# 기존 Calico CR 정리 (CRD는 유지, clean-ns에서 삭제)
echo "=== Cleaning up old Calico CRs ==="

# Installation/APIServer CR 삭제
kubectl patch installation default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
kubectl delete installation default --force --grace-period=0 --wait=false 2>/dev/null || true
kubectl patch apiserver default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
kubectl delete apiserver default --force --grace-period=0 --wait=false 2>/dev/null || true

# IPPool 삭제 (있으면)
for pool in $(kubectl get ippool -o name 2>/dev/null || true); do
  kubectl patch "$pool" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$pool" --force --grace-period=0 2>/dev/null || true
done

# Calico 관련 namespace 내 리소스 정리
for ns in calico-system calico-apiserver; do
  if kubectl get ns "$ns" &>/dev/null; then
    kubectl delete deploy,ds,sts --all -n "$ns" --force --grace-period=0 2>/dev/null || true
    kubectl delete pods --all -n "$ns" --force --grace-period=0 2>/dev/null || true
  fi
done

# Installation/APIServer 삭제 대기
echo "Waiting for CRs to be deleted..."
for i in {1..10}; do
  if ! kubectl get installation default &>/dev/null && ! kubectl get apiserver default &>/dev/null; then
    echo "  Old CRs cleaned"
    break
  fi
  kubectl patch installation default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl patch apiserver default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  sleep 2
done

# Step 0: 노드 어노테이션 정리 (WireGuard IP 충돌 방지)
echo "=== Step 0: Cleaning node annotations ==="
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  kubectl annotate node "$node" projectcalico.org/IPv4Address- 2>/dev/null || true
  kubectl annotate node "$node" projectcalico.org/IPv4VXLANTunnelAddr- 2>/dev/null || true
done
echo "Node annotations cleaned."

# Step 1: Tigera Operator 설치
echo ""
echo "=== Step 1: Installing Tigera Operator ==="
kubectl apply --server-side --force-conflicts -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"

echo "Waiting for Tigera Operator deployment..."
kubectl wait --for=condition=Available deployment/tigera-operator -n tigera-operator --timeout=${TIMEOUT}s

# tigera-operator를 CP 노드에 배치
echo "Patching tigera-operator to run on CP node..."
kubectl patch deployment tigera-operator -n tigera-operator --type=json -p='[
  {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"kubernetes.io/hostname": "control-plane-1"}},
  {"op": "add", "path": "/spec/template/spec/tolerations", "value": [{"key": "node-role.kubernetes.io/control-plane", "operator": "Exists", "effect": "NoSchedule"}]}
]' 2>/dev/null || true
kubectl rollout status deployment/tigera-operator -n tigera-operator --timeout=60s || true

echo "Waiting for Installation CRD..."
for i in {1..60}; do
  if kubectl get crd installations.operator.tigera.io &>/dev/null; then
    kubectl wait --for=condition=Established crd/installations.operator.tigera.io --timeout=30s && break
  fi
  echo "  Waiting for CRD... ($i/60)"
  sleep 3
done

# Step 2: Installation CR 생성 (항상 삭제 후 재생성)
echo ""
echo "=== Step 2: Creating Calico Installation ==="

# 기존 Installation 삭제 (있으면)
if kubectl get installation default &>/dev/null; then
  echo "Deleting existing Installation..."
  kubectl patch installation default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete installation default --force --grace-period=0 --wait=false 2>/dev/null || true
  sleep 3
fi

# 기존 APIServer 삭제 (있으면)
if kubectl get apiserver default &>/dev/null; then
  echo "Deleting existing APIServer..."
  kubectl patch apiserver default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete apiserver default --force --grace-period=0 --wait=false 2>/dev/null || true
  sleep 2
fi

# Installation이 완전히 삭제될 때까지 대기
for i in {1..15}; do
  if ! kubectl get installation default &>/dev/null; then
    break
  fi
  echo "  Waiting for Installation to be deleted... ($i/15)"
  kubectl patch installation default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  sleep 2
done

echo "Creating new Installation..."
cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Calico 컨트롤 플레인을 CP 노드에 배치 (typha, kube-controllers)
  controlPlaneNodeSelector:
    kubernetes.io/hostname: control-plane-1
  controlPlaneTolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
  calicoNetwork:
    ipPools:
    - cidr: ${POD_CIDR}
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
    nodeAddressAutodetectionV4:
      cidrs:
      - ${NODE_CIDR}
  # Felix 메트릭 활성화 (Prometheus 스크래핑용)
  nodeMetricsPort: 9091
EOF

# Step 3: APIServer 설치
echo ""
echo "=== Step 3: Creating Calico APIServer ==="
for i in {1..30}; do
  if kubectl get crd apiservers.operator.tigera.io &>/dev/null; then
    kubectl wait --for=condition=Established crd/apiservers.operator.tigera.io --timeout=30s && break
  fi
  sleep 2
done

echo "Creating APIServer..."
cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF

# Step 4: calico-system namespace 대기
echo ""
echo "=== Step 4: Waiting for Calico to be ready ==="
echo "Waiting for calico-system namespace..."
for i in {1..90}; do
  if kubectl get ns calico-system &>/dev/null; then
    echo "  calico-system namespace created."
    break
  fi
  echo "  Waiting for namespace... ($i/90)"
  sleep 2
done

if ! kubectl get ns calico-system &>/dev/null; then
  echo "❌ calico-system namespace not created."
  echo "Installation status:"
  kubectl get installation default -o yaml | grep -A15 status || true
  exit 1
fi

# Step 5: calico-node DaemonSet 대기
echo ""
echo "Waiting for calico-node DaemonSet to be created..."
for i in {1..60}; do
  if kubectl get daemonset -n calico-system calico-node &>/dev/null; then
    echo "  calico-node DaemonSet found."
    break
  fi
  echo "  Waiting for DaemonSet... ($i/60)"
  sleep 3
done

echo "Waiting for calico-node to be ready (timeout: ${TIMEOUT}s)..."
kubectl rollout status daemonset/calico-node -n calico-system --timeout=${TIMEOUT}s || {
  echo ""
  echo "⚠️  calico-node not fully ready yet."
  echo ""
  echo "Current status:"
  kubectl get pods -n calico-system
  echo ""
  echo "Check logs if needed:"
  echo "  kubectl logs -n calico-system -l k8s-app=calico-node --tail=50"
  echo ""
  echo "Continuing anyway... (may work after a moment)"
}

echo ""
echo "=== Calico Installation Complete ==="
echo ""
kubectl get pods -n calico-system
echo ""
echo "Node IPs:"
kubectl get nodes -o wide
