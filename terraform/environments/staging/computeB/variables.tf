#############################################
# Account & Owner Variables
#############################################

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile for test account (계정 B)"
  type        = string
  # 필수: terraform.tfvars에서 설정
}

variable "main_account_profile" {
  description = "AWS CLI profile for main account (계정 A) - Route53 접근용"
  type        = string
  default     = "default"
}

variable "owner_name" {
  description = "Owner tag value (필수: ktcloud_team4_260204 등)"
  type        = string
  # 필수: terraform.tfvars에서 설정

  validation {
    condition     = length(var.owner_name) > 0
    error_message = "owner_name is required. Set your identifier (e.g., ktcloud_team4_260204) in terraform.tfvars."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

#############################################
# Main Account References (Cross-Account)
#############################################

variable "main_account_id" {
  description = "Main AWS Account ID (계정 A) - ECR, Route53 소유"
  type        = string
  # 필수: terraform.tfvars에서 설정
}

variable "ecr_registry_url" {
  description = "ECR Registry URL from main account"
  type        = string
  # 예: 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com
}

#############################################
# VPC Variables
#############################################

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.1.11.0/24", "10.1.12.0/24"]
}

#############################################
# Bastion Variables
#############################################

variable "bastion_instance_type" {
  description = "Bastion EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "bastion_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to bastion"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.bastion_allowed_cidrs) > 0
    error_message = "bastion_allowed_cidrs must not be empty. Set allowed CIDR blocks in terraform.tfvars."
  }
}

variable "bastion_key_name" {
  description = "SSH key pair name for bastion"
  type        = string
  default     = ""

  validation {
    condition     = var.bastion_key_name == "" || lower(var.bastion_key_name) != "your-key-pair"
    error_message = "bastion_key_name must be an existing EC2 key pair name or empty to use SSM only. Do not leave the placeholder value."
  }
}

variable "bastion_root_volume_size" {
  description = "Root volume size in GB for bastion"
  type        = number
  default     = 30

  validation {
    condition     = var.bastion_root_volume_size >= 30
    error_message = "bastion_root_volume_size must be at least 30 GB for the current Amazon Linux 2023 AMI."
  }
}

#############################################
# EKS Variables
#############################################

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "goormgb-staging"
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to access EKS API endpoint publicly"
  type        = list(string)

  validation {
    condition     = length(var.eks_public_access_cidrs) > 0
    error_message = "eks_public_access_cidrs must not be empty."
  }
}

variable "eks_cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.34"
}

variable "eks_on_demand_instance_types" {
  description = "EKS ON_DEMAND node instance types"
  type        = list(string)
  default     = ["t4g.medium"]
}

variable "eks_on_demand_desired_size" {
  description = "EKS ON_DEMAND node group desired size"
  type        = number
  default     = 1
}

variable "eks_on_demand_min_size" {
  description = "EKS ON_DEMAND node group minimum size"
  type        = number
  default     = 1
}

variable "eks_on_demand_max_size" {
  description = "EKS ON_DEMAND node group maximum size"
  type        = number
  default     = 2
}

variable "eks_spot_instance_types" {
  description = "EKS SPOT node instance types"
  type        = list(string)
  default     = ["t4g.medium", "t4g.large"]
}

variable "eks_spot_desired_size" {
  description = "EKS SPOT node group desired size"
  type        = number
  default     = 0
}

variable "eks_spot_min_size" {
  description = "EKS SPOT node group minimum size"
  type        = number
  default     = 0
}

variable "eks_spot_max_size" {
  description = "EKS SPOT node group maximum size"
  type        = number
  default     = 3
}

#############################################
# RDS Variables
#############################################

variable "db_engine_version" {
  description = "PostgreSQL engine version (major version recommended)"
  type        = string
  default     = "16"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "RDS max allocated storage in GB"
  type        = number
  default     = 50
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "goormgb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.db_username) > 0 &&
      length(var.db_username) <= 16 &&
      can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.db_username)) &&
      lower(var.db_username) != "admin"
    )
    error_message = "db_username must start with a letter, use only letters/numbers/underscore, be 1-16 characters, and must not be the reserved word 'admin'."
  }
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 12 && var.db_password != "CHANGE_ME_STRONG_PASSWORD"
    error_message = "db_password must be at least 12 characters and must not use the placeholder value."
  }
}

variable "adopt_existing_secrets" {
  description = "Deprecated and ignored. Use scripts/import-existing-secrets.sh when you need to adopt pre-existing secrets into state."
  type        = bool
  default     = false
}

#############################################
# ElastiCache Variables
#############################################

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_cache_node_type" {
  description = "ElastiCache Redis node type for cache"
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_queue_node_type" {
  description = "ElastiCache Redis node type for queue"
  type        = string
  default     = "cache.t4g.micro"
}
