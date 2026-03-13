#############################################
# DNS - staging.playball.one
#############################################

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "goormgb-tf-state"
    key            = "dns/staging/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "goormgb-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project     = "goormgb"
      ManagedBy   = "terraform"
      Environment = "staging"
      Layer       = "dns"
    }
  }
}

# CloudFront ACM은 us-east-1 필수
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "goormgb"
      ManagedBy   = "terraform"
      Environment = "staging"
      Layer       = "dns"
    }
  }
}

data "aws_caller_identity" "current" {}
