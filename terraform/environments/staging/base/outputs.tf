#############################################
# ECR Outputs
#############################################

output "ecr_web_repository_urls" {
  description = "ECR web service repository URLs"
  value = {
    for k, v in aws_ecr_repository.web : k => v.repository_url
  }
}

output "ecr_ai_repository_urls" {
  description = "ECR AI service repository URLs"
  value = {
    for k, v in aws_ecr_repository.ai : k => v.repository_url
  }
}

#############################################
# IAM Outputs
#############################################

output "cn_staging_access_policy_arn" {
  description = "CN group staging access policy ARN"
  value       = aws_iam_policy.cn_staging_access.arn
}
