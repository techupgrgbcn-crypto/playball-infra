#############################################
# S3 Bucket for Terraform State
#############################################

resource "aws_s3_bucket" "tf_state" {
  bucket = "goormgb-tf-state"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "${var.project_name}-tf-state-bucket"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#############################################
# S3 Bucket for Secret JSON Files
#############################################

resource "aws_s3_bucket" "secret_store" {
  bucket = "${var.project_name}-secret-store"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "${var.project_name}-secret-store"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secret_store" {
  bucket = aws_s3_bucket.secret_store.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "secret_store" {
  bucket = aws_s3_bucket.secret_store.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "secret_store" {
  bucket = aws_s3_bucket.secret_store.id

  versioning_configuration {
    status = "Enabled"
  }
}

#############################################
# DynamoDB Table for State Locking
#############################################

resource "aws_dynamodb_table" "tf_lock" {
  name         = "${var.project_name}-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-tf-lock"
  }
}
