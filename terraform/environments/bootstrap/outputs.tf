output "state_bucket_name" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.tf_state.id
}

output "state_bucket_arn" {
  description = "Terraform state S3 bucket ARN"
  value       = aws_s3_bucket.tf_state.arn
}

output "secret_bucket_name" {
  description = "S3 Bucket for AWS SM"
  value = aws_s3_bucket.secret_store.id
}

output "secret_bucket_arn" {
  description = "AWS SM S3 bucket ARN"
  value = aws_s3_bucket.secret_store.arn
}

output "lock_table_name" {
  description = "DynamoDB table for state locking"
  value       = aws_dynamodb_table.tf_lock.id
}

output "lock_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.tf_lock.arn
}

output "next_steps" {
  description = "다음 단계 안내"
  value       = <<-EOT

    Bootstrap 완료!

    생성된 리소스:
    - S3: ${aws_s3_bucket.tf_state.id}
    - DynamoDB: ${aws_dynamodb_table.tf_lock.id}

    다음 단계:
    1. cd ../common/existing
    2. terraform init
    3. terraform import (기존 리소스)
    4. terraform apply

  EOT
}
