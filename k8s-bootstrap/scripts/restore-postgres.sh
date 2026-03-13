#!/bin/bash
# ============================================================================
# PostgreSQL S3 백업 복원 스크립트
# ============================================================================
#
# 개요:
#   S3에 저장된 PostgreSQL 백업을 복원하는 스크립트입니다.
#   매일 오전 3시(UTC)에 자동 백업된 파일을 사용합니다.
#
# 사전 요구사항:
#   - kubectl 설치 및 클러스터 접근 권한
#   - aws cli 설치 및 인증 설정 (aws configure)
#   - data 네임스페이스에 postgresql-credentials, postgresql-backup-s3 secret 존재
#
# ============================================================================
# 사용법
# ============================================================================
#
# 1. 백업 목록 확인 (인자 없이 실행):
#    ./scripts/restore-postgres.sh
#
# 2. 특정 백업 파일로 복원:
#    ./scripts/restore-postgres.sh backup-20260225-082317.sql.gz
#
# ============================================================================
# 백업 파일 검색 방법
# ============================================================================
#
# 1. 최근 백업 목록 (스크립트 사용):
#    ./scripts/restore-postgres.sh
#
# 2. AWS CLI로 직접 검색:
#    aws s3 ls s3://goormgb-backup/dev/postgres/goormgb/ --region ap-northeast-2
#
# 3. 특정 날짜 백업 검색:
#    aws s3 ls s3://goormgb-backup/dev/postgres/goormgb/ | grep "20260225"
#
# 4. 가장 최신 백업 확인:
#    aws s3 ls s3://goormgb-backup/dev/postgres/goormgb/ | sort -r | head -1
#
# ============================================================================
# 백업 파일 형식
# ============================================================================
#
# 파일명: backup-YYYYMMDD-HHMMSS.sql.gz
# 경로: s3://goormgb-backup/dev/postgres/goormgb/
# 예시: s3://goormgb-backup/dev/postgres/goormgb/backup-20260225-082317.sql.gz
#
# ============================================================================
# 복원 시 주의사항
# ============================================================================
#
# - 복원 시 기존 데이터가 덮어쓰기 될 수 있습니다!
# - 중요한 데이터는 복원 전 현재 상태를 먼저 백업하세요:
#   kubectl create job --from=cronjob/postgresql-3am-s3-backup manual-backup -n data
#
# - 복원은 트랜잭션 단위로 수행되지 않습니다.
#   복원 중 오류 발생 시 데이터가 일부만 복원될 수 있습니다.
#
# ============================================================================

set -e

S3_BUCKET="goormgb-backup"
S3_PREFIX="dev/postgres"
DATABASE="goormgb"
NAMESPACE="data"

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  PostgreSQL S3 Backup Restore Tool${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# 백업 파일 인자 확인
BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
    echo -e "${YELLOW}[INFO] 사용 가능한 백업 목록 (최근 20개):${NC}"
    echo ""
    aws s3 ls s3://${S3_BUCKET}/${S3_PREFIX}/${DATABASE}/ --region ap-northeast-2 | sort -r | head -20
    echo ""
    echo "----------------------------------------"
    echo -e "${YELLOW}사용법:${NC}"
    echo "  $0 <backup-file>"
    echo ""
    echo -e "${YELLOW}예시:${NC}"
    echo "  $0 backup-20260225-082317.sql.gz"
    echo ""
    echo -e "${YELLOW}특정 날짜 검색:${NC}"
    echo "  aws s3 ls s3://${S3_BUCKET}/${S3_PREFIX}/${DATABASE}/ | grep \"20260225\""
    echo "----------------------------------------"
    exit 0
fi

# 백업 파일 존재 여부 확인
echo -e "${YELLOW}[CHECK] 백업 파일 존재 여부 확인 중...${NC}"
if ! aws s3 ls s3://${S3_BUCKET}/${S3_PREFIX}/${DATABASE}/${BACKUP_FILE} --region ap-northeast-2 > /dev/null 2>&1; then
    echo -e "${RED}[ERROR] 백업 파일을 찾을 수 없습니다: ${BACKUP_FILE}${NC}"
    echo ""
    echo "사용 가능한 백업 목록:"
    aws s3 ls s3://${S3_BUCKET}/${S3_PREFIX}/${DATABASE}/ --region ap-northeast-2 | sort -r | head -10
    exit 1
fi
echo -e "${GREEN}[OK] 백업 파일 확인됨${NC}"
echo ""

echo -e "${YELLOW}[INFO] 복원 정보:${NC}"
echo "  Database:  ${DATABASE}"
echo "  Namespace: ${NAMESPACE}"
echo "  Backup:    ${BACKUP_FILE}"
echo "  S3 Path:   s3://${S3_BUCKET}/${S3_PREFIX}/${DATABASE}/${BACKUP_FILE}"
echo ""

# 확인
echo -e "${RED}=========================================="
echo "  WARNING: 이 작업은 기존 데이터를 덮어씁니다!"
echo -e "==========================================${NC}"
echo ""
read -p "계속하시겠습니까? (yes 입력): " confirm
if [ "$confirm" != "yes" ]; then
    echo ""
    echo "취소되었습니다."
    exit 0
fi

echo ""
echo -e "${GREEN}[START] 복원 Job 생성 중...${NC}"

JOB_NAME="postgresql-restore-$(date +%Y%m%d-%H%M%S)"

# Job 생성
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  namespace: ${NAMESPACE}
spec:
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: control-plane-1
      tolerations:
        - key: "node-role.kubernetes.io/control-plane"
          operator: "Exists"
          effect: "NoSchedule"
      containers:
        - name: restore
          image: postgres:16-alpine
          env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: postgresql-credentials
                  key: POSTGRES_USER
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql-credentials
                  key: POSTGRES_PASSWORD
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: postgresql-backup-s3
                  key: AWS_ACCESS_KEY_ID
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: postgresql-backup-s3
                  key: AWS_SECRET_ACCESS_KEY
            - name: AWS_DEFAULT_REGION
              value: ap-northeast-2
          command:
            - /bin/sh
            - -c
            - |
              set -e
              apk add --no-cache aws-cli

              echo ""
              echo "=== [1/3] Downloading backup from S3 ==="
              aws s3 cp s3://${S3_BUCKET}/${S3_PREFIX}/${DATABASE}/${BACKUP_FILE} /tmp/restore.sql.gz
              echo "Download complete."

              echo ""
              echo "=== [2/3] Extracting backup file ==="
              gunzip /tmp/restore.sql.gz
              echo "Extract complete. Size: \$(du -h /tmp/restore.sql | cut -f1)"

              echo ""
              echo "=== [3/3] Restoring database ==="
              psql -h postgresql -U \$POSTGRES_USER -d ${DATABASE} < /tmp/restore.sql

              echo ""
              echo "=========================================="
              echo "  RESTORE COMPLETE!"
              echo "=========================================="
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
EOF

echo ""
echo -e "${GREEN}[OK] Job 생성됨: ${JOB_NAME}${NC}"
echo ""
echo -e "${YELLOW}[LOG] 복원 로그:${NC}"
echo "----------------------------------------"

# Pod 시작 대기
sleep 3

# 로그 follow
kubectl logs -f job/${JOB_NAME} -n ${NAMESPACE} 2>/dev/null || {
    echo "Pod 시작 대기 중..."
    sleep 5
    kubectl logs -f job/${JOB_NAME} -n ${NAMESPACE}
}

echo "----------------------------------------"
echo ""
echo -e "${GREEN}[DONE] 복원 작업 완료!${NC}"
echo ""
echo -e "${YELLOW}[CLEANUP] Job 정리 명령어:${NC}"
echo "  kubectl delete job ${JOB_NAME} -n ${NAMESPACE}"
echo ""
