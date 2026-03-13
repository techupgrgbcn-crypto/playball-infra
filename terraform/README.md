# Terraform Infrastructure

> AWS Infrastructure as Code using Terraform

## Structure

```
terraform/
└── environments/
    └── staging/
        ├── base/           # Account A: Shared resources
        │   ├── route53.tf
        │   ├── cloudfront.tf
        │   ├── ecr.tf
        │   └── iam.tf
        │
        └── compute/        # Account B: Compute resources
            ├── vpc.tf
            ├── eks.tf
            ├── rds.tf
            ├── elasticache.tf
            └── bastion.tf
```

## Deployment Order

1. `staging/base` - Deploy shared resources first
2. `staging/compute` - Deploy compute resources

## Usage

```bash
cd environments/staging/base
terraform init
terraform plan
terraform apply
```

## Cross-Account Architecture

- **Account A (base)**: Route53, CloudFront, ECR, ACM
- **Account B (compute)**: VPC, EKS, RDS, ElastiCache

Cross-account ECR pull is enabled via IAM policies.
