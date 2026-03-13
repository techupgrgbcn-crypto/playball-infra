#!/usr/bin/env bash
set -euo pipefail

# Route53 API 연결 테스트
# Usage: ./scripts/ddns/test-api.sh

DOMAIN="${DOMAIN:-goormgb.space}"
HOSTED_ZONE_ID="${HOSTED_ZONE_ID:-ZEXAMPLEZONEID}"

echo "=== Route53 API Test ==="

# 1. AWS credentials 확인
echo ""
echo "[1/4] AWS credentials..."
if aws sts get-caller-identity &>/dev/null; then
  IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text)
  echo "  -> OK: ${IDENTITY}"
else
  echo "  -> ERROR: AWS credentials not configured"
  exit 1
fi

# 2. 현재 공인 IP 확인
echo ""
echo "[2/4] Current public IP..."
CURRENT_IP=$(curl -sf https://api.ipify.org)
echo "  -> ${CURRENT_IP}"

# 3. Hosted Zone 확인
echo ""
echo "[3/4] Hosted Zone..."
ZONE_NAME=$(aws route53 get-hosted-zone --id "$HOSTED_ZONE_ID" --query 'HostedZone.Name' --output text 2>/dev/null || echo "ERROR")
if [ "$ZONE_NAME" = "ERROR" ]; then
  echo "  -> ERROR: Hosted Zone not found (ID: ${HOSTED_ZONE_ID})"
  exit 1
fi
echo "  -> OK: ${ZONE_NAME} (ID: ${HOSTED_ZONE_ID})"

# 4. 현재 DNS 레코드 조회
echo ""
echo "[4/4] Current A records for ${DOMAIN}..."
aws route53 list-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --query "ResourceRecordSets[?Type=='A'].[Name,ResourceRecords[0].Value]" \
  --output table

echo ""
echo "=== Test Complete ==="
