# Staging ComputeB - 테스트 계정 (계정 B)

테스트/교육용 AWS 계정에 배포되는 컴퓨팅 리소스입니다.

## 아키텍처

```
┌─────────────────────────────────────────┐
│          계정 A (Main Account)           │
│  Route53, CloudFront, ECR, ACM          │
└─────────────────┬───────────────────────┘
                  │
                  ▼ Cross-Account Access
┌─────────────────────────────────────────┐
│          계정 B (Test Account)           │
│  VPC, EKS, RDS, ElastiCache, Bastion    │
│  Secrets Manager (별도)                   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │ Owner: ktcloud_team4_260204      │   │
│  │ 모든 리소스에 Owner 태그 포함      │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

---

## 사용법

### Step 1: 사전 준비

#### 1-1. AWS CLI 프로필 설정

```bash
# 테스트 계정 프로필 추가
aws configure --profile ktcloud-test
# AWS Access Key ID: [테스트 계정 키 입력]
# AWS Secret Access Key: [테스트 계정 시크릿 입력]
# Default region name: ap-northeast-2
# Default output format: json

# 프로필 확인
aws sts get-caller-identity --profile ktcloud-test
```

#### 1-2. 메인 계정 ECR Cross-Account 설정

메인 계정의 `staging/base/terraform.tfvars`에 테스트 계정 ID 추가:

```hcl
ecr_allowed_account_ids = ["987654321098"]
```

```bash
cd ../base
terraform apply
```

### Step 2: Bootstrap 배포 (최초 1회)

computeB-bootstrap에서 Terraform state용 S3/DynamoDB와 secret JSON 저장용 S3 생성:

```bash
cd ../computeB-bootstrap

# tfvars 설정
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

```hcl
aws_profile = "ktcloud-test"
owner_name  = "ktcloud_team4_260204"
```

```bash
# 배포
terraform init
terraform apply

# 생성된 state 버킷명 확인
terraform output -raw tfstate_bucket
terraform output -raw secret_store_bucket
terraform output -raw tflock_table

# State를 S3로 이전
terraform init -migrate-state
```

### Step 3: Terraform 입력값 준비

`.env` 파일은 Terraform 실행에 필요한 입력값만 관리합니다.

```bash
# .env 파일 생성 (gitignore에 포함됨)
cat > .env << 'EOF'
# AWS
TF_VAR_aws_profile=ktcloud-test
TF_VAR_owner_name=ktcloud_team4_260204
TF_VAR_main_account_profile=default
TF_VAR_main_account_id=123456789012
TF_VAR_ecr_registry_url=123456789012.dkr.ecr.ap-northeast-2.amazonaws.com

# Network Access
TF_VAR_bastion_allowed_cidrs='["YOUR_IP/32"]'
TF_VAR_eks_public_access_cidrs='["YOUR_IP/32"]'
TF_VAR_bastion_key_name=

# Database
TF_VAR_db_username=goormgb_app
TF_VAR_db_password=YourStrongPassword123!
EOF
```

주의:

- `TF_VAR_db_username`, `TF_VAR_db_password`는 RDS 생성에 직접 사용됩니다.
- `TF_VAR_db_username=admin` 은 RDS PostgreSQL 예약어라서 사용할 수 없습니다.
- 애플리케이션용 시크릿은 `.env`가 아니라 아래 `staging/secrets.json`에서 관리합니다.
- `TF_VAR_bastion_key_name`은 선택사항입니다. 비워두면 SSH 키 대신 SSM으로 접속합니다.
- bastion root volume은 기본 30GB를 사용합니다. 별도 조정이 필요하면 `TF_VAR_bastion_root_volume_size`로 override할 수 있습니다.
- RDS PostgreSQL은 patch 버전 고정보다 호환성이 높은 major version `16`을 기본값으로 사용합니다.

### Step 4: `secrets.json` 준비 및 업로드

`common/secrets-manager`는 `s3://<secret_store_bucket>/staging/secrets.json`을 읽고, `secrets_manager.tf` 에 정의된 키를 Secrets Manager로 생성합니다.

```bash
cat > secrets.json << 'EOF'
{
  "webhook-github": "CHANGE_ME_WEBHOOK_SECRET",
  "discord-webhook": {},
  "discord-webhook-alerts": {},
  "argocd": {},
  "google": {},
  "cloudflare": {},
  "s3-backup": {},
  "redis-cache": {},
  "redis-queue": {},
  "kakao": {},
  "jwt": {},
  "redis": {},
  "db": {
    "username": "goormgb_app",
    "password": "YourStrongPassword123!"
  },
  "grafana": {},
  "github-ssh": {}
}
EOF

aws s3 cp secrets.json \
  "s3://$(cd ../computeB-bootstrap && terraform output -raw secret_store_bucket)/staging/secrets.json" \
  --profile ktcloud-test
```

주의:

- 최상위 키 이름은 `webhook-github`, `discord-webhook`, `discord-webhook-alerts`, `argocd`, `google`, `cloudflare`, `s3-backup`, `redis-cache`, `redis-queue`, `kakao`, `jwt`, `redis`, `db`, `grafana`, `github-ssh`를 그대로 사용해야 합니다.
- 각 값의 내부 JSON 구조는 실제로 해당 시크릿을 읽는 애플리케이션/차트가 기대하는 형식에 맞춰 작성해야 합니다.
- `db` 항목의 값은 `TF_VAR_db_username`, `TF_VAR_db_password`와 일치시키는 편이 안전합니다.

### Step 5: ComputeB 배포

```bash
cd ../computeB

# 환경 변수 로드
set -a && source .env && set +a

# 또는 direnv 사용시
# echo "dotenv" > .envrc && direnv allow

# Terraform 실행
terraform init \
  -backend-config="bucket=$(cd ../computeB-bootstrap && terraform output -raw tfstate_bucket)" \
  -backend-config="dynamodb_table=$(cd ../computeB-bootstrap && terraform output -raw tflock_table)"

# computeB는 bootstrap과 동일한 규칙의 secret store 버킷
# goormgb-secret-store-<ACCOUNT_ID> 에서 staging/secrets.json 을 읽음
# EKS node group 기본 instance type은 ARM 계열(t4g.*)입니다.
terraform plan
terraform apply
```

### Step 6: EKS 접속 설정

```bash
# kubeconfig 설정
aws eks update-kubeconfig \
    --name $(terraform output -raw cluster_name) \
    --region ap-northeast-2 \
    --profile ktcloud-test

# 클러스터 확인
kubectl get nodes
kubectl get pods -A
```

---

## 일상 운영

### 변경사항 적용

```bash
# 환경 변수 로드
set -a && source .env && set +a

# Plan 확인
terraform plan

# 적용
terraform apply
```

### 특정 리소스만 재생성

```bash
# EKS 노드 그룹만 재생성
terraform apply -replace="module.eks.aws_eks_node_group.this[\"on_demand\"]"

# RDS만 재생성 (주의: 데이터 손실!)
terraform apply -replace="aws_db_instance.main"
```

### 출력값 확인

```bash
# 전체 출력
terraform output

# 특정 값
terraform output cluster_endpoint
terraform output rds_endpoint
terraform output bastion_public_ip
```

---

## 리소스 네이밍

모든 리소스는 `{owner_name}-{environment}-{resource}` 형식으로 생성됩니다.

| 리소스 | 이름 예시 |
|--------|----------|
| VPC | `ktcloud_team4_260204-staging-vpc` |
| EKS | `ktcloud_team4_260204-goormgb-staging` |
| RDS | `ktcloud-team4-260204-staging-postgresql` |
| Redis | `ktcloud-team4-260204-redis-cache` |
| Bastion | `ktcloud_team4_260204-staging-bastion` |

AWS 이름 제약이 있는 일부 리소스 식별자(RDS identifier, DB/Redis parameter group, ElastiCache cluster, EKS IAM role)는 `owner_name`을 소문자로 바꾸고, 영문 소문자/숫자/하이픈이 아닌 문자를 `-`로 치환한 값을 사용합니다.

---

## 파일 구조

```
computeB/
├── providers.tf          # AWS Provider (Owner 태그 포함)
├── variables.tf          # 변수 정의
├── data.tf               # 데이터 소스
├── vpc.tf                # VPC, 서브넷, NAT
├── bastion.tf            # Bastion 호스트
├── eks.tf                # EKS 클러스터 + Addons
├── rds.tf                # RDS PostgreSQL
├── elasticache.tf        # ElastiCache Redis
├── secrets_manager.tf    # Secrets Manager from secret store bucket
├── outputs.tf            # 출력값
├── argocd-values.yaml    # ArgoCD Helm values
├── terraform.tfvars.example
└── .env                  # Terraform 입력값 (gitignore)
```

---

## 비용 정보

| 리소스 | 스펙 | 예상 비용 (월) |
|--------|------|---------------|
| NAT Gateway | 1개 | ~$32 |
| EKS Control Plane | - | $73 |
| EKS Node (t4g.medium) | 1대 | ~$27 |
| RDS (db.t4g.micro) | 1대 | ~$12 |
| ElastiCache (cache.t4g.micro) | 2대 | ~$18 |
| Bastion (t3.micro) | 1대 | ~$8 |
| **합계** | | **~$170/월** |

---

## 삭제

```bash
# 환경 변수 로드
set -a && source .env && set +a

# 리소스 삭제
terraform destroy

# State 파일 정리 (완전 삭제시)
aws s3 rm "s3://$(cd ../computeB-bootstrap && terraform output -raw tfstate_bucket)/staging/computeB/" --recursive --profile ktcloud-test
```

---

## 트러블슈팅

### ECR 이미지 Pull 실패

```bash
# 에러: ImagePullBackOff

# 1. 메인 계정 ECR에 Cross-Account 정책 확인
aws ecr get-repository-policy \
    --repository-name staging/playball/web/api-gateway \
    --profile default

# 2. 노드에서 ECR 인증 테스트
aws ecr get-login-password --region ap-northeast-2 --profile ktcloud-test | \
    docker login --username AWS --password-stdin \
    123456789012.dkr.ecr.ap-northeast-2.amazonaws.com
```

### EKS 접근 실패

```bash
# 에러: Unable to connect to the server

# 1. 현재 IP 확인
curl -s ifconfig.me

# 2. eks_public_access_cidrs에 IP 추가 후 재적용
terraform apply

# 3. kubeconfig 재설정
aws eks update-kubeconfig \
    --name $(terraform output -raw cluster_name) \
    --region ap-northeast-2 \
    --profile ktcloud-test
```

### Bastion 생성 실패

`InvalidBlockDeviceMapping` 에러가 나면 현재 Amazon Linux 2023 AMI 스냅샷보다 루트 볼륨이 작다는 뜻입니다. 기본값은 30GB이며, 더 크게 써야 하면 `TF_VAR_bastion_root_volume_size`를 설정합니다.

### RDS 엔진 버전 에러

`Cannot find version ... for postgres` 에러가 나면 patch 버전이 더 이상 해당 리전에서 제공되지 않는 경우가 많습니다. 기본값은 major version `16`이며, 특별한 이유가 없으면 major version만 유지하는 편이 안전합니다.

### Secrets Manager 삭제 대기 에러

`You can't create this secret because a secret with this name is already scheduled for deletion.` 에러가 나면, 기존 시크릿이 삭제 대기 상태입니다. 이미 삭제를 걸어둔 시크릿은 먼저 복구해야 합니다.

```bash
aws secretsmanager restore-secret --secret-id staging/services/db --profile ktcloud-test
```

필요한 `staging/...` 시크릿들에 대해 같은 방식으로 복구한 뒤 `terraform apply`를 다시 실행하세요. 현재 구성은 이후 `terraform destroy` 시 computeB 시크릿을 즉시 삭제하도록 바꿔서, 같은 이름으로 바로 재생성할 수 있게 했습니다.

### Secrets Manager 이미 존재 에러

`ResourceExistsException: ... secret ... already exists` 는 이전 apply가 AWS에는 시크릿을 만들었지만 Terraform state에는 아직 없는 상태입니다. 이때는 create가 아니라 import가 맞습니다.

```bash
./scripts/import-existing-secrets.sh ktcloud-test
```

기존 `staging/...` 시크릿들 중 AWS에 이미 있는 것만 state로 가져옵니다. 그런 다음 `terraform apply`를 다시 실행하세요. 이 스크립트는 존재하는 시크릿만 import하므로, `destroy -> apply`를 반복하는 일반 흐름을 방해하지 않습니다.

### EKS Add-ons / Helm 인증 에러

`Kubernetes cluster unreachable` 또는 `aws-ebs-csi-driver ... DEGRADED`가 초기 배포 중 보이면, 먼저 노드 그룹이 정상 생성되는지 확인해야 합니다. 이 구성은 클러스터 생성자 admin 권한을 활성화하고, node group 생성 후 add-on/Helm이 시작되도록 대기하도록 조정돼 있습니다. 일부 리소스가 먼저 실패했다면 값을 수정한 뒤 `terraform apply`를 다시 실행하면 됩니다.

### Terraform state lock 에러

```bash
# 에러: Error acquiring the state lock

# Lock 강제 해제 (주의!)
terraform force-unlock <LOCK_ID>
```

### Bastion SSH 접속

```bash
# SSH 키페어 사용
ssh -i ~/.ssh/your-keypair.pem ec2-user@$(terraform output -raw bastion_public_ip)

# 또는 SSM 사용 (키페어 없이)
aws ssm start-session \
    --target $(terraform output -raw bastion_instance_id) \
    --profile ktcloud-test
```
