#!/usr/bin/env bash
set -euo pipefail

# 모든 팀원 kubeconfig 일괄 생성
# k3s server 노드에서 실행

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

USERS=(
  "team-member-1"
  "team-member-2"
  "team-member-3"
)

echo "=== Creating kubeconfig for all team members ==="
echo ""

for user in "${USERS[@]}"; do
  "$SCRIPT_DIR/create-user-kubeconfig.sh" "$user"
  echo ""
done

echo "=== All kubeconfigs created ==="
echo ""
echo "생성된 파일:"
for user in "${USERS[@]}"; do
  echo "  - ${user}.kubeconfig"
done
