#!/usr/bin/env bash
set -euo pipefail

# Calico CNI 설치 (Helm 버전)
# - Tigera Operator 공식 Helm 차트 사용
# - ArgoCD 관리로 인계 가능

CALICO_VERSION="${CALICO_VERSION:-v3.29.3}"
POD_CIDR="${POD_CIDR:-10.244.0.0/16}"
NODE_CIDR="${NODE_CIDR:-10.0.0.0/24}"
TIMEOUT="${TIMEOUT:-300}"
CP_NODE="${CP_NODE:-control-plane-1}"

echo "=== Installing Calico CNI (Helm) ==="
echo "  Version: $CALICO_VERSION"
echo "  Pod CIDR: $POD_CIDR"
echo "  Node CIDR: $NODE_CIDR (for IP autodetection)"
echo "  CP Node: $CP_NODE"
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

# Helm repo 추가
echo "=== Adding Tigera Operator Helm repo ==="
helm repo add projectcalico https://docs.tigera.io/calico/charts 2>/dev/null || true
helm repo update projectcalico

# 기존 Calico 정리 (있으면)
echo "=== Cleaning up old Calico resources ==="

# 기존 raw manifest로 설치된 operator 삭제
if kubectl get deployment tigera-operator -n tigera-operator &>/dev/null; then
  if ! helm status calico -n tigera-operator &>/dev/null; then
    echo "Found raw manifest installation. Cleaning up..."
    kubectl patch installation default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    kubectl delete installation default --force --grace-period=0 --wait=false 2>/dev/null || true
    kubectl patch apiserver default -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    kubectl delete apiserver default --force --grace-period=0 --wait=false 2>/dev/null || true

    # IPPool 삭제
    for pool in $(kubectl get ippool -o name 2>/dev/null || true); do
      kubectl patch "$pool" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
      kubectl delete "$pool" --force --grace-period=0 2>/dev/null || true
    done

    # Calico 관련 리소스 정리
    for ns in calico-system calico-apiserver; do
      if kubectl get ns "$ns" &>/dev/null; then
        kubectl delete deploy,ds,sts --all -n "$ns" --force --grace-period=0 2>/dev/null || true
        kubectl delete pods --all -n "$ns" --force --grace-period=0 2>/dev/null || true
      fi
    done

    # Operator 삭제
    kubectl delete deployment tigera-operator -n tigera-operator --force --grace-period=0 2>/dev/null || true
    kubectl delete ns tigera-operator --force --grace-period=0 2>/dev/null || true

    echo "Waiting for cleanup..."
    sleep 10
  fi
fi

# 노드 어노테이션 정리
echo "=== Cleaning node annotations ==="
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  kubectl annotate node "$node" projectcalico.org/IPv4Address- 2>/dev/null || true
  kubectl annotate node "$node" projectcalico.org/IPv4VXLANTunnelAddr- 2>/dev/null || true
done

# Helm으로 Calico 설치
echo ""
echo "=== Installing Calico via Helm ==="

# values.yaml 생성
VALUES_FILE=$(mktemp)
cat > "$VALUES_FILE" <<EOF
# Tigera Operator Helm values
installation:
  enabled: true
  spec:
    controlPlaneNodeSelector:
      kubernetes.io/hostname: ${CP_NODE}
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
    nodeMetricsPort: 9091

apiServer:
  enabled: true
  spec: {}

tigeraOperator:
  nodeSelector:
    kubernetes.io/hostname: ${CP_NODE}
  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
EOF

helm upgrade --install calico projectcalico/tigera-operator \
  --namespace tigera-operator \
  --create-namespace \
  --version "$CALICO_VERSION" \
  --values "$VALUES_FILE" \
  --wait \
  --timeout "${TIMEOUT}s"

rm -f "$VALUES_FILE"

# calico-node DaemonSet 대기
echo ""
echo "=== Waiting for Calico to be ready ==="
echo "Waiting for calico-system namespace..."
for i in {1..90}; do
  if kubectl get ns calico-system &>/dev/null; then
    echo "  calico-system namespace created."
    break
  fi
  echo "  Waiting for namespace... ($i/90)"
  sleep 2
done

echo "Waiting for calico-node DaemonSet..."
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
}

echo ""
echo "=== Calico Installation Complete (Helm) ==="
echo ""
kubectl get pods -n calico-system
echo ""
echo "Helm release:"
helm list -n tigera-operator
echo ""
echo "Node IPs:"
kubectl get nodes -o wide
