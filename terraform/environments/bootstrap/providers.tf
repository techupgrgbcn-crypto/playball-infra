#############################################
# Terraform & Provider Configuration
# Bootstrap: Local Backend 사용 (처음 시작용)
#############################################

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bootstrap은 local backend 사용
  # S3 버킷 생성 후에는 다른 환경에서 S3 backend 사용
}

provider "aws" {
  region = var.aws_region
}
