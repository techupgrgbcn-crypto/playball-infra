variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

#############################################
# TODO: Graviton (ARM) 인스턴스 사용 시 Docker 빌드 변경 필요
#############################################
#
# 1. Dockerfile 멀티 아키텍처 빌드:
#    FROM --platform=linux/arm64 eclipse-temurin:21-jre-alpine
#
# 2. docker buildx 사용:
#    docker buildx build --platform linux/arm64 -t <image> .
#
# 3. ECR 푸시 시 ARM 이미지 태그 확인
#
# 4. Spring Boot (Java): ARM 네이티브 지원 (별도 설정 불필요)
# 5. FastAPI (Python): ARM 네이티브 지원 (별도 설정 불필요)
#
#############################################

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
  default     = []  # terraform.tfvars에서 설정 필요!

  validation {
    condition     = length(var.bastion_allowed_cidrs) > 0
    error_message = "bastion_allowed_cidrs must not be empty. Set allowed CIDR blocks in terraform.tfvars."
  }
}

variable "bastion_key_name" {
  description = "SSH key pair name for bastion"
  type        = string
  default     = ""
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
  description = "CIDR blocks allowed to access EKS API endpoint publicly (필수 - tfvars에 설정)"
  type        = list(string)
  # 기본값 없음 - 보안상 tfvars에서 명시적으로 설정 필요

  validation {
    condition     = length(var.eks_public_access_cidrs) > 0
    error_message = "eks_public_access_cidrs must not be empty. Set allowed CIDR blocks to access the EKS public endpoint."
  }
}

variable "eks_cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.29"
}

# ON_DEMAND Node Group (인프라 + 기본 앱)
# Graviton (ARM): t4g가 t3 대비 20% 저렴
variable "eks_on_demand_instance_types" {
  description = "EKS ON_DEMAND node instance types (Graviton ARM)"
  type        = list(string)
  default     = ["t4g.medium"]  # Graviton: $0.0368/hr (t3.medium: $0.0464/hr)
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

# SPOT Node Group (앱 스케일링)
# Graviton (ARM) + x86 혼합으로 가용성 최대화
variable "eks_spot_instance_types" {
  description = "EKS SPOT node instance types (Graviton ARM 우선, x86 fallback)"
  type        = list(string)
  default     = ["t4g.medium", "t4g.large", "t3.medium", "t3.large"]  # ARM 우선
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
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"
}

variable "db_instance_class" {
  description = "RDS instance class (Graviton ARM)"
  type        = string
  default     = "db.t4g.micro"  # Graviton: $0.021/hr (db.t3.micro: $0.026/hr, 19% 저렴)
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "RDS max allocated storage in GB (autoscaling)"
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
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
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
  description = "ElastiCache Redis node type for cache (Graviton ARM)"
  type        = string
  default     = "cache.t4g.micro"  # Graviton: $0.014/hr (cache.t3.micro: $0.017/hr, 18% 저렴)
}

variable "redis_queue_node_type" {
  description = "ElastiCache Redis node type for queue (Graviton ARM)"
  type        = string
  default     = "cache.t4g.micro"  # Graviton: $0.014/hr (cache.t3.micro: $0.017/hr, 18% 저렴)
}
