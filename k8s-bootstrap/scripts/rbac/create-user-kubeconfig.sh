#!/usr/bin/env bash
set -euo pipefail

# 팀원용 kubeconfig 생성 스크립트
# kubeadm control plane 노드에서 실행 (sudo 필요)
#
# Usage: ./create-user-kubeconfig.sh <username>
# Example: ./create-user-kubeconfig.sh team-member-1
#
# 결과: ./<username>.kubeconfig 파일 생성

USERNAME="${1:-}"

if [[ -z "$USERNAME" ]]; then
  echo "Usage: $0 <username>"
  echo "Example: $0 team-member-1"
  exit 1
fi

# kubeadm CA 위치
CA_CERT="/etc/kubernetes/pki/ca.crt"
CA_KEY="/etc/kubernetes/pki/ca.key"

# CP 노드 실제 IP 가져오기 (VPN 접속용)
# 127.0.0.1이 아닌 실제 내부 IP 사용
CP_IP=$(hostname -I | awk '{print $1}')
SERVER_URL="https://${CP_IP}:6443"

echo "Using server: $SERVER_URL"

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

echo "=== Creating kubeconfig for: $USERNAME ==="

# 1. 개인 키 생성
openssl genrsa -out "$WORK_DIR/${USERNAME}.key" 2048

# 2. CSR 생성 (CN = username, O = team-viewer 그룹)
openssl req -new \
  -key "$WORK_DIR/${USERNAME}.key" \
  -out "$WORK_DIR/${USERNAME}.csr" \
  -subj "/CN=${USERNAME}/O=team-viewer"

# 3. CA로 서명 (30일 유효)
sudo openssl x509 -req \
  -in "$WORK_DIR/${USERNAME}.csr" \
  -CA "$CA_CERT" \
  -CAkey "$CA_KEY" \
  -CAcreateserial \
  -out "$WORK_DIR/${USERNAME}.crt" \
  -days 30

# 4. kubeconfig 생성
cat > "${USERNAME}.kubeconfig" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $(sudo cat "$CA_CERT" | base64 | tr -d '\n')
    server: ${SERVER_URL}
  name: kubeadm
contexts:
- context:
    cluster: kubeadm
    user: ${USERNAME}
  name: ${USERNAME}@kubeadm
current-context: ${USERNAME}@kubeadm
users:
- name: ${USERNAME}
  user:
    client-certificate-data: $(cat "$WORK_DIR/${USERNAME}.crt" | base64 | tr -d '\n')
    client-key-data: $(cat "$WORK_DIR/${USERNAME}.key" | base64 | tr -d '\n')
EOF

echo ""
echo "=== Created: ${USERNAME}.kubeconfig ==="
echo ""
echo "팀원에게 전달:"
echo "  1. ${USERNAME}.kubeconfig 파일 전송"
echo "  2. 팀원 PC에서: export KUBECONFIG=~/${USERNAME}.kubeconfig"
echo "  3. 또는: cp ${USERNAME}.kubeconfig ~/.kube/config"
echo ""
echo "유효기간: 30일 (갱신 필요)"
echo ""
echo "⚠️  RBAC 설정 필요 (최초 1회):"
echo "  kubectl apply -f scripts/rbac/team-viewer-rbac.yaml"
