# Staging Environment

스테이징 환경 인프라 구성입니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                       계정 A (Main Account)                      │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                    staging/base                          │   │
│   │         Route53, CloudFront, ECR, ACM                    │   │
│   └─────────────────────────┬───────────────────────────────┘   │
│                             │                                    │
│                      CloudFront Origin                           │
│                             │                                    │
│   ┌─────────────────────────▼───────────────────────────────┐   │
│   │                  staging/compute (A)                     │   │
│   │              VPC, EKS, RDS, ElastiCache                  │   │
│   └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Cross-Account
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       계정 B (Test Account)                      │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                 staging/computeB                         │   │
│   │              VPC, EKS, RDS, ElastiCache                  │   │
│   │              Owner: ktcloud_team4_260204                 │   │
│   └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 디렉토리 구조

```
staging/
├── base/                 # 계정 A: Route53, CloudFront, ECR
├── compute/              # 계정 A: VPC, EKS, RDS (운영)
├── computeB/             # 계정 B: VPC, EKS, RDS (테스트)
└── computeB-bootstrap/   # 계정 B: Terraform State (S3, DynamoDB)
```

---

## 전환 흐름 (computeB → computeA)

### Phase 1: computeB 배포 (테스트 계정)

```bash
# 1. Bootstrap 배포 (최초 1회)
cd staging/computeB-bootstrap
terraform init && terraform apply

# 2. ComputeB 배포
cd ../computeB
set -a && source .env && set +a
terraform init && terraform apply

# 3. NLB DNS 확인
kubectl get svc -n istio-system istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
# 출력: k8s-istiosys-xxx.elb.ap-northeast-2.amazonaws.com
```

### Phase 2: CloudFront 연결

```bash
# 4. staging/base에 NLB DNS 입력
cd ../base
vi terraform.tfvars
```

```hcl
# staging/base/terraform.tfvars
api_nlb_domain        = "k8s-istiosys-xxx.elb.ap-northeast-2.amazonaws.com"  # computeB
monitoring_nlb_domain = "k8s-istiosys-xxx.elb.ap-northeast-2.amazonaws.com"  # computeB
```

```bash
# 5. CloudFront Origin 연결
terraform apply
```

### Phase 3: 테스트 완료 후 computeA 전환

```bash
# 6. ComputeA 배포 (메인 계정)
cd ../compute
terraform init && terraform apply

# 7. NLB DNS 확인
kubectl get svc -n istio-system istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
# 출력: k8s-istiosys-yyy.elb.ap-northeast-2.amazonaws.com

# 8. staging/base tfvars 업데이트
cd ../base
vi terraform.tfvars
```

```hcl
# staging/base/terraform.tfvars
api_nlb_domain        = "k8s-istiosys-yyy.elb.ap-northeast-2.amazonaws.com"  # computeA
monitoring_nlb_domain = "k8s-istiosys-yyy.elb.ap-northeast-2.amazonaws.com"  # computeA
```

```bash
# 9. CloudFront Origin 전환
terraform apply

# 10. computeB 삭제
cd ../computeB
terraform destroy
```

---

## 주요 파일

| 경로 | 용도 |
|------|------|
| `base/terraform.tfvars` | CloudFront Origin (NLB DNS) 설정 |
| `base/cloudfront.tf` | CloudFront 배포 설정 |
| `computeB/.env` | 테스트 계정 Terraform 입력값 (gitignore) |
| `computeB/terraform.tfvars` | 테스트 계정 설정 |

---

## 상세 문서

- [ComputeB 사용법](./computeB/README.md)
- [ComputeB Bootstrap](./computeB-bootstrap/README.md)
