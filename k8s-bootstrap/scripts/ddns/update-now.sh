#!/usr/bin/env bash
set -euo pipefail

# DDNS 즉시 업데이트 (CronJob 안 기다리고 수동 실행)
# Usage: ./scripts/ddns/update-now.sh

NAMESPACE="${DDNS_NAMESPACE:-infra}"
CRONJOB_NAME="ddns-cloudflare-updater"

echo "=== DDNS Manual Update ==="

if ! kubectl get cronjob "$CRONJOB_NAME" -n "$NAMESPACE" &>/dev/null; then
  echo "ERROR: CronJob '${CRONJOB_NAME}' not found in namespace '${NAMESPACE}'"
  echo "ArgoCD가 helm repo에서 DDNS를 배포했는지 확인하세요."
  exit 1
fi

# CronJob에서 수동 Job 생성
JOB_NAME="ddns-manual-$(date +%s)"
kubectl create job "$JOB_NAME" --from="cronjob/${CRONJOB_NAME}" -n "$NAMESPACE"

echo "Job '${JOB_NAME}' created. Waiting for completion..."
kubectl wait --for=condition=complete "job/${JOB_NAME}" -n "$NAMESPACE" --timeout=60s 2>/dev/null || true

echo ""
echo "=== Job Logs ==="
kubectl logs "job/${JOB_NAME}" -n "$NAMESPACE" 2>/dev/null || echo "(waiting for pod to start...)"

echo ""
echo "Cleanup: kubectl delete job ${JOB_NAME} -n ${NAMESPACE}"
