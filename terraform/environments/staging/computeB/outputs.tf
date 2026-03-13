#############################################
# Outputs - Test Account (계정 B)
#############################################

#############################################
# VPC
#############################################

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

#############################################
# EKS
#############################################

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster CA data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "eks_kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --profile ${var.aws_profile}"
}

#############################################
# Bastion
#############################################

output "bastion_public_ip" {
  description = "Bastion host public IP"
  value       = aws_eip.bastion.public_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion"
  value       = var.bastion_key_name != "" ? "ssh -i ~/.ssh/${var.bastion_key_name}.pem ec2-user@${aws_eip.bastion.public_ip}" : "Use SSM: aws ssm start-session --target ${aws_instance.bastion.id}"
}

#############################################
# RDS
#############################################

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "RDS PostgreSQL address (hostname only)"
  value       = aws_db_instance.main.address
}

#############################################
# ElastiCache
#############################################

output "redis_cache_endpoint" {
  description = "Redis cache endpoint"
  value       = aws_elasticache_cluster.cache.cache_nodes[0].address
}

output "redis_queue_endpoint" {
  description = "Redis queue endpoint"
  value       = aws_elasticache_cluster.queue.cache_nodes[0].address
}

#############################################
# Cross-Account Info
#############################################

output "owner_name" {
  description = "Resource owner name"
  value       = var.owner_name
}

output "ecr_registry" {
  description = "ECR registry URL (main account)"
  value       = var.ecr_registry_url
}
