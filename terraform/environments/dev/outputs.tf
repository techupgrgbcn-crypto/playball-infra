#############################################
# ECR Outputs
#############################################

output "ecr_repository_urls" {
  description = "ECR service repository URLs"
  value = {
    for k, v in aws_ecr_repository.service : k => v.repository_url
  }
}

#############################################
# IAM Outputs
#############################################

output "dev_dev_access_policy_arn" {
  description = "DEV group dev access policy ARN"
  value       = aws_iam_policy.dev_dev_access.arn
}

output "cn_dev_access_policy_arn" {
  description = "CN group dev access policy ARN"
  value       = aws_iam_policy.cn_dev_access.arn
}

#############################################
# Secrets Manager Outputs
#############################################

output "argocd_webhook_github_secret_arn" {
  description = "ArgoCD GitHub webhook secret ARN"
  value       = aws_secretsmanager_secret.argocd_webhook_github.arn
}

output "argocd_webhook_github_secret_value" {
  description = "ArgoCD GitHub webhook secret value (use this in GitHub webhook settings)"
  value       = random_password.argocd_webhook_github.result
  sensitive   = true
}
