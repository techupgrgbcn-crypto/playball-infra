#############################################
# S3 Outputs (신규 버킷)
#############################################

output "s3_ai_data_bucket" {
  description = "AI data bucket name"
  value       = aws_s3_bucket.ai_data.id
}

output "s3_ai_backup_bucket" {
  description = "AI backup bucket name"
  value       = aws_s3_bucket.ai_backup.id
}

#############################################
# IAM Group Outputs (신규 그룹)
#############################################

output "iam_group_cs_arn" {
  description = "CS IAM Group ARN"
  value       = aws_iam_group.cs.arn
}

output "iam_group_dev_arn" {
  description = "DEV IAM Group ARN"
  value       = aws_iam_group.dev.arn
}

output "iam_group_pm_arn" {
  description = "PM IAM Group ARN"
  value       = aws_iam_group.pm.arn
}
