#############################################
# S3 Bucket: Backup (신규 생성)
#############################################
resource "aws_s3_bucket" "backup" {
  bucket = "goormgb-backup"

  tags = {
    Name = "goormgb-backup"
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  # Dev PostgreSQL 백업: 7일 후 삭제
  rule {
    id     = "dev-postgres-7days"
    status = "Enabled"

    filter {
      prefix = "dev/postgres/"
    }

    expiration {
      days = 7
    }
  }

  # Dev 로그: 7일 후 삭제
  rule {
    id     = "dev-logs-7days"
    status = "Enabled"

    filter {
      prefix = "dev/logs/"
    }

    expiration {
      days = 7
    }
  }

  # Staging PostgreSQL 백업: 14일 후 Glacier, 60일 후 삭제
  rule {
    id     = "staging-postgres-lifecycle"
    status = "Enabled"

    filter {
      prefix = "staging/postgres/"
    }

    transition {
      days          = 14
      storage_class = "GLACIER"
    }

    expiration {
      days = 60
    }
  }

  # Staging 로그: 14일 후 삭제
  rule {
    id     = "staging-logs-14days"
    status = "Enabled"

    filter {
      prefix = "staging/logs/"
    }

    expiration {
      days = 14
    }
  }

  # Prod PostgreSQL 백업: 30일 후 Glacier, 365일 후 삭제
  rule {
    id     = "prod-postgres-lifecycle"
    status = "Enabled"

    filter {
      prefix = "prod/postgres/"
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  # Prod 로그: 30일 후 Glacier, 90일 후 삭제
  rule {
    id     = "prod-logs-lifecycle"
    status = "Enabled"

    filter {
      prefix = "prod/logs/"
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 90
    }
  }
}

#############################################
# S3 Bucket: Assets (신규 생성)
#############################################
resource "aws_s3_bucket" "assets" {
  bucket = "goormgb-assets"

  tags = {
    Name = "goormgb-assets"
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = false  # static/clubs/ 퍼블릭 정책 허용
  ignore_public_acls      = true
  restrict_public_buckets = false  # static/clubs/ 퍼블릭 접근 허용
}

# static/clubs/ 경로만 퍼블릭 읽기 허용 (구단 로고)
resource "aws_s3_bucket_policy" "assets_public_clubs" {
  bucket = aws_s3_bucket.assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadClubLogos"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.assets.arn}/static/clubs/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.assets]
}

#############################################
# S3 Bucket: AI Data (모델, 학습데이터, 이미지) - 신규
#############################################
resource "aws_s3_bucket" "ai_data" {
  bucket = "goormgb-ai-data"

  tags = {
    Name = "goormgb-ai-data"
    Team = "AI"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ai_data" {
  bucket = aws_s3_bucket.ai_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "ai_data" {
  bucket = aws_s3_bucket.ai_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#############################################
# S3 Bucket: AI Backup (AI 모델 백업) - 신규
#############################################
resource "aws_s3_bucket" "ai_backup" {
  bucket = "goormgb-ai-backup"

  tags = {
    Name = "goormgb-ai-backup"
    Team = "AI"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ai_backup" {
  bucket = aws_s3_bucket.ai_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "ai_backup" {
  bucket = aws_s3_bucket.ai_backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
