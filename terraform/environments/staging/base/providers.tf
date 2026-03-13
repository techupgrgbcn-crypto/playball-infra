terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "goormgb-tf-state"
    key            = "staging/base/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "goormgb-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "goormgb"
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}

# ACM 인증서용 (CloudFront는 us-east-1 필요)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "goormgb"
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}
