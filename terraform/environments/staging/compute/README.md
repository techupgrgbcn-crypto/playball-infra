# Staging Compute Environment

스테이징 환경의 컴퓨팅 리소스를 관리합니다. 비용 절감을 위해 필요시 삭제할 수 있는 리소스들입니다.

## 리소스 목록

### EKS (`eks.tf`)

EKS Blueprints 패턴을 사용하여 클러스터와 애드온을 관리합니다.

**클러스터:**
| 항목 | 값 |
|------|-----|
| 이름 | `goormgb-staging` |
| 버전 | `1.29` |
| Endpoint | Public + Private |

**Node Groups:**
| 그룹 | 타입 | 크기 | 용도 |
|------|------|------|------|
| on-demand | ON_DEMAND | 1-2 | 인프라 + 기본 앱 |
| spot | SPOT | 0-3 | 앱 스케일링 (taint 적용) |

**EKS Blueprints Addons:**
| 애드온 | 설명 |
|--------|------|
| CoreDNS | DNS 서비스 |
| VPC-CNI | 네트워크 플러그인 |
| Kube-proxy | 네트워크 프록시 |
| EBS CSI Driver | EBS 볼륨 지원 |
| AWS Load Balancer Controller | NLB/ALB 생성 |
| External Secrets Operator | Secrets Manager 연동 |
| ArgoCD | GitOps 배포 |

**ArgoCD App of Apps:**
- Repository: `git@github.com:goorm-gongbang/303-goormgb-k8s-helm.git`
- Branch: `argocd-sync/staging`
- Path: `staging/root`

### RDS (`rds.tf`)

| 항목 | 값 |
|------|-----|
| Engine | PostgreSQL 16.3 |
| Instance | db.t3.micro |
| Storage | 20-50 GB (autoscaling) |
| Multi-AZ | false (staging) |

### ElastiCache (`elasticache.tf`)

| 클러스터 | 용도 | 노드 타입 |
|----------|------|----------|
| redis-cache | 캐시 | cache.t3.micro |
| redis-queue | 큐 | cache.t3.micro |

### Bastion (`bastion.tf`)

| 항목 | 값 |
|------|-----|
| Instance | t3.micro |
| AMI | Amazon Linux 2023 |
| EIP | 고정 IP 할당 |

### Route53 Records (`route53_records.tf`)

| 레코드 | 타입 | 대상 |
|--------|------|------|
| bastion.staging.playball.one | A | Bastion EIP |

## Base 레이어 참조

`data.tf`에서 base 레이어의 출력값을 참조합니다:

```hcl
locals {
  vpc_id             = data.terraform_remote_state.base.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.base.outputs.private_subnet_ids
  staging_zone_id    = data.terraform_remote_state.base.outputs.staging_zone_id
  staging_acm_arn    = data.terraform_remote_state.base.outputs.staging_acm_arn
}
```

## 사용법

```bash
# base 레이어가 먼저 apply 되어 있어야 함
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### 비용 절감을 위한 삭제

```bash
terraform destroy -var-file="terraform.tfvars"
```

> base 레이어는 유지되므로 다시 apply하면 복구됩니다.
