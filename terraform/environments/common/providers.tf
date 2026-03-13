terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "goormgb-tf-state"
    key            = "common/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "goormgb-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "goormgb"
      ManagedBy = "terraform"
    }
  }
}

#############################################
# Data Sources
#############################################

data "aws_caller_identity" "current" {}
