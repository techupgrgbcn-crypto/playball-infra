# GoormGB Terraform Environments

## 구조

```
environments/
├── dns/
│   ├── root/           # playball.one 루트 도메인
│   └── staging/        # staging.playball.one 서브도메인
└── staging/
    └── base/           # VPC, EKS, CloudFront 등 인프라
```

## 각 환경 설명

| 환경 | 설명 | 주요 리소스 |
|------|------|-------------|
| `dns/root` | 루트 도메인 관리 | Route53 (playball.one), ACM (*.playball.one), Assets CDN |
| `dns/staging` | staging 서브도메인 | Route53 (staging.playball.one), ACM (*.staging.playball.one) |
| `staging/base` | staging 인프라 | VPC, EKS, CloudFront (API/Monitoring) |

## 의존성 관계

```
dns/root (1차)     dns/staging
    │                  │
    │ Porkbun NS       │ NS 출력
    ▼                  ▼
dns/root (2차) ◄── staging NS 복사
    │
    │ NS 레코드 위임
    ▼
staging/base
```

---

## 배포 (Deploy)

**순서대로 실행** (의존성 때문에 순서 중요!)

### 1. dns/root (1차 - Route53만)

```bash
cd environments/dns/root
# terraform.tfvars: enable_acm = false
terraform init
terraform apply
```

> output의 NS 레코드를 Porkbun에 설정

### 2. dns/staging

```bash
cd environments/dns/staging
terraform init
terraform apply

# output에서 NS 복사
terraform output zone_name_servers
```

### 3. dns/root (2차 - NS 위임 + ACM)

```bash
cd environments/dns/root
# terraform.tfvars에 staging NS 복사
# enable_acm = true 로 변경
terraform apply
```

### 4. staging/base

```bash
cd environments/staging/base
terraform init
terraform apply
```

---

## 삭제 (Destroy)

**역순으로 실행** (의존성 때문에 순서 중요!)

### 1. staging/base

```bash
cd environments/staging/base
terraform destroy
```

### 2. dns/root (NS 위임 레코드 제거)

```bash
cd environments/dns/root
# terraform.tfvars: staging_zone_name_servers = []
terraform apply
```

### 3. dns/staging

```bash
cd environments/dns/staging
terraform destroy
```

### 4. dns/root (완전 삭제)

```bash
cd environments/dns/root
terraform destroy
```

---

## 주의사항

### ACM 인증서
- CloudFront용 ACM은 **us-east-1** 리전 필수
- ALB/NLB용 ACM은 **ap-northeast-2** 리전

### NS 위임 확인
dns/root 배포 후 Porkbun에서 NS 레코드 설정 필요:
```bash
# Route53 NS 확인
aws route53 get-hosted-zone --id <ZONE_ID> --query 'DelegationSet.NameServers'
```

### State 파일
- 모든 환경은 S3 backend 사용 (`goormgb-tf-state` 버킷)
- DynamoDB로 state locking (`goormgb-tf-lock` 테이블)

### 환경별 State Key
| 환경 | State Key |
|------|-----------|
| dns/root | `dns/root/terraform.tfstate` |
| dns/staging | `dns/staging/terraform.tfstate` |
| staging/base | `staging/base/terraform.tfstate` |

---

## 자주 쓰는 명령어

```bash
# 현재 상태 확인
terraform show

# 특정 리소스만 재생성
terraform apply -replace="aws_instance.example"

# State에서 리소스 제거 (실제 리소스는 유지)
terraform state rm <resource_address>

# 기존 리소스 import
terraform import <resource_address> <resource_id>

# Plan 결과 저장
terraform plan -out=tfplan
terraform apply tfplan
```
