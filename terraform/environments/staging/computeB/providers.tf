#############################################
# Staging ComputeB - 테스트 계정 (계정 B)
# VPC, EKS, RDS, ElastiCache 등 컴퓨팅 리소스
#############################################

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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }

  # 테스트 계정(계정 B)의 S3 버킷 사용
  # computeB-bootstrap을 먼저 실행하여 S3/DynamoDB 생성 필요
  backend "s3" {
    key     = "staging/computeB/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}

#############################################
# AWS Provider - 테스트 계정 (계정 B)
#############################################

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile # 테스트 계정 프로필

  # 모든 리소스에 Owner 태그 자동 추가
  default_tags {
    tags = {
      Project     = "goormgb"
      Environment = "staging"
      ManagedBy   = "terraform"
      Owner       = var.owner_name # 필수: ktcloud_team4_260204 등
    }
  }
}

# ACM 인증서용 (CloudFront는 us-east-1 필요)
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
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

#############################################
# AWS Provider - 메인 계정 (계정 A)
# Route53 레코드 생성에 사용
#############################################

provider "aws" {
  alias   = "main_account"
  region  = var.aws_region
  profile = var.main_account_profile # 메인 계정 프로필

  default_tags {
    tags = {
      Project     = "goormgb"
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}

#############################################
# Kubernetes Provider (EKS 클러스터 연결)
#############################################

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--profile", var.aws_profile]
  }
}

#############################################
# Helm Provider (ArgoCD 등 설치)
#############################################

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--profile", var.aws_profile]
    }
  }
}

#############################################
# Kubectl Provider (kubectl_manifest 리소스용)
#############################################

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--profile", var.aws_profile]
  }
}
