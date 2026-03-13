# 301-goormgb-terraform

Goorm Gongbang 프로젝트의 AWS 인프라를 관리하는 Terraform 코드입니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                      계정 A (Main Account)                       │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   Route53   │  │  CloudFront │  │     ECR     │              │
│  │   (DNS)     │  │   (CDN)     │  │  (Images)   │              │
│  └─────────────┘  └─────────────┘  └──────┬──────┘              │
│                                           │ Cross-Account Pull   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    dev environment                        │   │
│  │         VPC, EKS, RDS, ElastiCache, Secrets              │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ Cross-Account
┌─────────────────────────────────────────────────────────────────┐
│                      계정 B (Test Account)                       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              staging/computeB environment                 │   │
│  │         VPC, EKS, RDS, ElastiCache, Secrets              │   │
│  │                                                           │   │
│  │              Owner: ktcloud_team4_260204                  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 디렉토리 구조

```
.
├── environments/
│   ├── bootstrap/              # Terraform Backend (S3, DynamoDB)
│   ├── common/                 # 환경 공통 리소스 (IAM, S3)
│   ├── dev/                    # 개발 환경 (계정 A)
│   ├── dns/                    # DNS 관리
│   │   ├── root/               # 루트 도메인 (playball.one)
│   │   └── staging/            # 스테이징 도메인
│   └── staging/                # 스테이징 환경
│       ├── base/               # 계정 A: CloudFront, ECR, Route53
│       ├── compute/            # 계정 A: VPC, EKS (기존)
│       ├── computeB/           # 계정 B: VPC, EKS (테스트용)
│       └── computeB-bootstrap/ # 계정 B: Terraform State
└── modules/                    # 재사용 모듈
```

## Environments

### bootstrap
Terraform 상태 관리를 위한 초기 설정
- S3 Secret Store (Secrets Manager)
- S3 Backend (terraform state)
- DynamoDB (state lock)

### common
모든 환경에서 공유하는 리소스
- **IAM**: 사용자, 그룹, 봇 계정
- **S3**: 백업, Assets, AI 데이터 버킷

### dev
개발 환경 (계정 A)
- **ECR**: 컨테이너 이미지
- **Secrets Manager**: 애플리케이션 시크릿
- **VPC/EKS**: 컴퓨팅 리소스

### staging

| 디렉토리 | 계정 | 설명 |
|----------|------|------|
| `base/` | A | CloudFront, ECR, Route53 레코드 |
| `compute/` | A | VPC, EKS, RDS (기존 구조) |
| `computeB/` | B | VPC, EKS, RDS (테스트 계정) |
| `computeB-bootstrap/` | B | Terraform State (S3, DynamoDB) |

### dns
도메인 및 인증서 관리
- **root/**: playball.one 루트 도메인
- **staging/**: staging.playball.one 서브도메인

스테이징 환경 전용 리소스 (구축 중)
- **SECRET_MANAGER**: 민감정보 저장
  + `./enviroments/common/secrets-manager/main.tf` 에서 어떤 S3의 파일을 참조하는지 결정 (S3에서는 <환경>/secrets.json 으로 저장
  + 자세한 구조는 `./enviroments/test/secrets.tf` 참고
  + 테라폼 버전 1.11 이상부터 해당 코드로 구동 가능합니다 (그냥 brew install terraform 했다면 1.5 버전일것)

### prod

프로덕션 환경 전용 리소스 (예정)

### test
테스트용 폴더


## 사용법

### 개발 환경 (Dev)

```bash
cd environments/dev

# tfvars 설정
vi terraform.tfvars

# 배포
terraform init
terraform plan
terraform apply
```

### 스테이징 환경 (Staging - 테스트 계정)

테스트 계정(계정 B)에 배포하는 경우:

```bash
# 1. Bootstrap (최초 1회)
cd environments/staging/computeB-bootstrap
terraform init && terraform apply
terraform init -migrate-state

# 2. ComputeB 배포
cd ../computeB

# .env 파일로 환경변수 설정
set -a && source .env && set +a

terraform init
terraform plan
terraform apply
```

자세한 사용법은 [computeB/README.md](./environments/staging/computeB/README.md) 참조

---

## Cross-Account 설정

### ECR 접근 허용

메인 계정(A)의 ECR에서 테스트 계정(B)의 이미지 Pull 허용:

```hcl
# environments/staging/base/terraform.tfvars
ecr_allowed_account_ids = ["987654321098"]
```

### Owner 태그

테스트 계정의 모든 리소스에 Owner 태그 자동 추가:

```hcl
# environments/staging/computeB/terraform.tfvars
owner_name = "ktcloud_team4_260204"
```

---

## 비용 정보

### Dev (계정 A)
| 리소스 | 예상 비용 |
|--------|----------|
| EKS Control Plane | $73/월 |
| EKS Nodes (on-demand + spot) | ~$50/월 |
| RDS PostgreSQL | ~$15/월 |
| ElastiCache Redis | ~$20/월 |
| NAT Gateway | ~$32/월 |

### Staging ComputeB (계정 B)
| 리소스 | 예상 비용 |
|--------|----------|
| EKS Control Plane | $73/월 |
| EKS Nodes (t4g.medium) | ~$27/월 |
| RDS (db.t4g.micro) | ~$12/월 |
| ElastiCache (cache.t4g.micro x2) | ~$18/월 |
| NAT Gateway | ~$32/월 |
| **합계** | **~$170/월** |

---

## CI/CD

| 도구 | 용도 | 봇 계정 |
|------|------|---------|
| TeamCity | 빌드 & ECR Push | bot-teamcity |
| ArgoCD | GitOps 배포 | bot-argocd |
| Cluster Jobs | 백업/인증 | bot-kubeadm |

---

## 관련 레포지토리

| 레포지토리 | 설명 |
|------------|------|
| 101-goormgb-frontend | 프론트엔드 (Next.js) |
| 102-goormgb-backend | 백엔드 (Spring Boot) |
| 302-goormgb-k8s-bootstrap | Kubernetes 부트스트랩 |
| 303-goormgb-k8s-helm | Helm Charts |

---

## 문서

- [Staging ComputeB 사용법](./environments/staging/computeB/README.md)
- [ComputeB Bootstrap](./environments/staging/computeB-bootstrap/README.md)
