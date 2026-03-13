#############################################
# ComputeB Bootstrap - 테스트 계정 (계정 B)
# S3 Backend + DynamoDB Lock 테이블 생성
#
# 이 모듈은 computeB보다 먼저 실행되어야 합니다.
# local backend로 먼저 생성 후 state를 S3로 이전
#############################################

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # 초기에는 local backend 사용
  # S3 생성 후 migrate 명령으로 이전
  # backend "local" {}

  # S3 생성 후 아래로 변경하고 terraform init -migrate-state 실행
   backend "s3" {
     bucket         = "goormgb-tf-state-987654321098"
     key            = "bootstrap/terraform.tfstate"
     region         = "ap-northeast-2"
     dynamodb_table = "goormgb-tf-lock-987654321098"
     encrypt        = true
  }
  # backend "local" {}
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "goormgb"
      Environment = "staging"
      ManagedBy   = "terraform"
      Owner       = var.owner_name
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id               = data.aws_caller_identity.current.account_id
  tfstate_bucket_name      = "goormgb-tf-state-${local.account_id}"
  secret_store_bucket_name = "goormgb-secret-store-${local.account_id}"
}

#############################################
# Variables
#############################################

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile for test account"
  type        = string
}

variable "owner_name" {
  description = "Owner tag value"
  type        = string
}

#############################################
# S3 Bucket for Terraform State
#############################################

resource "aws_s3_bucket" "tfstate" {
  bucket = local.tfstate_bucket_name

  # 실수로 삭제 방지
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = local.tfstate_bucket_name
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#############################################
# S3 Bucket for Secret JSON Files
#############################################

resource "aws_s3_bucket" "secret_store" {
  bucket = local.secret_store_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = local.secret_store_bucket_name
  }
}

resource "aws_s3_bucket_versioning" "secret_store" {
  bucket = aws_s3_bucket.secret_store.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secret_store" {
  bucket = aws_s3_bucket.secret_store.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "secret_store" {
  bucket = aws_s3_bucket.secret_store.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#############################################
# DynamoDB Table for State Lock
#############################################

resource "aws_dynamodb_table" "tflock" {
  name         = "goormgb-tf-lock-${local.account_id}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "goormgb-tf-lock-${local.account_id}"
  }
}

#############################################
# Outputs
#############################################

output "tfstate_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.tfstate.id
}

output "account_id" {
  description = "AWS account ID for the current profile"
  value       = local.account_id
}

output "secret_store_bucket" {
  description = "S3 bucket for shared secrets JSON files"
  value       = aws_s3_bucket.secret_store.id
}

output "tflock_table" {
  description = "DynamoDB table for Terraform lock"
  value       = aws_dynamodb_table.tflock.id
}

output "backend_config" {
  description = "Backend configuration for other modules"
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.tfstate.id}"
      key            = "staging/computeB/terraform.tfstate"
      region         = "${var.aws_region}"
      dynamodb_table = "${aws_dynamodb_table.tflock.id}"
      encrypt        = true
    }
  EOT
}
