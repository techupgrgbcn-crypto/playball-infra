#############################################
# Data Sources
#############################################

data "aws_caller_identity" "current" {}

#############################################
# Main Account Remote State (Route53, ACM)
# 메인 계정에서 dns/staging state 참조
#############################################

# Note: Cross-account remote state는 S3 bucket policy 필요
# 또는 terraform.tfvars에서 zone_id, acm_arn 직접 입력

#############################################
# Local values
#############################################

locals {
  owner_slug = replace(lower(var.owner_name), "/[^a-z0-9-]/", "-")

  # VPC (computeB에서 직접 관리)
  vpc_id             = aws_vpc.main.id
  vpc_cidr           = aws_vpc.main.cidr_block
  public_subnet_ids  = aws_subnet.public[*].id
  private_subnet_ids = aws_subnet.private[*].id

  # ECR (메인 계정 참조)
  ecr_registry = var.ecr_registry_url

  # Bootstrap과 같은 규칙으로 secret store 버킷명을 계산
  secret_store_bucket_name = "goormgb-secret-store-${data.aws_caller_identity.current.account_id}"

  # EKS cluster name must match subnet discovery tags.
  eks_cluster_full_name = "${var.owner_name}-${var.eks_cluster_name}"

  # AWS naming-constrained resources use a slugged owner value.
  rds_identifier                   = "${local.owner_slug}-${var.environment}-postgresql"
  rds_db_subnet_group_name         = "${local.owner_slug}-${var.environment}-db-subnet-group"
  rds_parameter_group_name         = "${local.owner_slug}-${var.environment}-postgresql-params"
  elasticache_subnet_group_name    = "${local.owner_slug}-${var.environment}-redis-subnet-group"
  elasticache_cache_parameter_name = "${local.owner_slug}-${var.environment}-redis-cache-params"
  elasticache_queue_parameter_name = "${local.owner_slug}-${var.environment}-redis-queue-params"
  elasticache_cache_cluster_id     = "${local.owner_slug}-redis-cache"
  elasticache_queue_cluster_id     = "${local.owner_slug}-redis-queue"

  # Avoid IAM name_prefix length failures in the EKS module.
  eks_cluster_iam_role_name   = "${local.owner_slug}-${var.environment}-eks"
  eks_on_demand_iam_role_name = "${local.owner_slug}-on-demand-ng"
  eks_spot_iam_role_name      = "${local.owner_slug}-spot-ng"
  eks_ebs_csi_irsa_role_name  = "${local.owner_slug}-ebs-csi"
}

#############################################
# AMI for Bastion
#############################################

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
