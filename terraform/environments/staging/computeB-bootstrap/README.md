# ComputeB Bootstrap - Terraform State 인프라

테스트 계정(계정 B)에 Terraform state 저장용 S3 + DynamoDB와 shared secret JSON용 S3를 생성합니다.
`goormgb-secret-store-<ACCOUNT_ID>/staging/secrets.json`은 `common/secrets-manager`와 `computeB/secrets_manager.tf`에서 읽습니다.

## 배포 순서

```
1. computeB-bootstrap (여기) → S3/DynamoDB/Secret Store 생성
2. computeB → VPC, EKS, RDS 등 생성
```

## 빠른 시작

### 1. tfvars 설정

```bash
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

### 2. 첫 배포 (Local Backend)

처음 실행 시 S3가 없으므로 기본값인 local backend를 그대로 사용합니다.

```bash
terraform init
terraform apply
```

### 3. State를 S3로 이전

S3/DynamoDB 생성 후, 출력된 계정 ID 기반 버킷명으로 backend를 S3로 변경합니다.

```hcl
# main.tf에서 backend "local"을 주석 처리하고 아래 backend "s3" 블록을 활성화
terraform {
  backend "s3" {
    bucket         = "goormgb-tf-state-<ACCOUNT_ID>"
    key            = "bootstrap/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "goormgb-tf-lock-<ACCOUNT_ID>"
    encrypt        = true
  }
}
```

```bash
terraform output -raw account_id
terraform output -raw tfstate_bucket
terraform output -raw secret_store_bucket
terraform output -raw tflock_table
terraform init -migrate-state
```

## 생성되는 리소스

| 리소스 | 이름 | 용도 |
|--------|------|------|
| S3 Bucket | `goormgb-tf-state-<ACCOUNT_ID>` | Terraform state 저장 |
| S3 Bucket | `goormgb-secret-store-<ACCOUNT_ID>` | `staging/secrets.json` 저장 |
| DynamoDB Table | `goormgb-tf-lock-<ACCOUNT_ID>` | State lock |

## 삭제 주의

**절대 삭제하지 마세요!** 이 리소스가 삭제되면 모든 terraform state가 사라집니다.

`prevent_destroy = true` 설정이 되어 있어 실수로 삭제되지 않습니다.
