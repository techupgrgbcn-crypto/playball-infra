#############################################
# IAM Policy: dev-web-developer-access
#############################################

resource "aws_iam_policy" "dev_dev_access" {
  name        = "DEV-Dev-Access"
  description = "DEV 그룹의 dev 환경 접근 권한"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRDescribeRepositories"
        Effect = "Allow"
        Action = [
          "ecr:DescribeRepositories",
          "ecr:DescribeRegistry"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRDevRepoRead"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/dev/goormgb/*"
      },
      {
        Sid    = "S3AssetsObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::goormgb-assets/dev/*"
      },
      {
        Sid    = "S3AssetsListBucket"
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = "arn:aws:s3:::goormgb-assets"
        Condition = {
          StringLike = {
            "s3:prefix" = ["dev/*"]
          }
        }
      },
      {
        Sid    = "SecretsManagerListOnly"
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:dev/*"
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "dev_dev_access" {
  group      = "DEV"  # common에서 관리하는 그룹
  policy_arn = aws_iam_policy.dev_dev_access.arn
}

#############################################
# CN 그룹 - Dev 환경 정책
#############################################

resource "aws_iam_policy" "cn_dev_access" {
  name        = "CN-Dev-Access"
  description = "CN 그룹의 dev 환경 접근 권한"
  path        = "/env/dev/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 - dev 백업 prefix Full Access
      {
        Sid    = "S3DevBackupObjects"
        Effect = "Allow"
        Action = "s3:*"
        Resource = "arn:aws:s3:::goormgb-backup/dev/*"
      },
      {
        Sid    = "S3DevBackupList"
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = "arn:aws:s3:::goormgb-backup"
        Condition = {
          StringLike = {
            "s3:prefix" = ["dev/*"]
          }
        }
      },
      # Secrets Manager - dev 시크릿 Full Access
      {
        Sid    = "SecretsManagerDev"
        Effect = "Allow"
        Action = "secretsmanager:*"
        Resource = "arn:aws:secretsmanager:*:*:secret:dev/*"
      },
      # ECR - dev 리포지토리 Full Access
      # (목록 조회는 common/CN-Common-Access에서 처리)
      {
        Sid    = "ECRDevFull"
        Effect = "Allow"
        Action = "ecr:*"
        Resource = "arn:aws:ecr:*:*:repository/dev/goormgb/*"
      },
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      # CloudWatch Logs - dev 로그
      {
        Sid    = "CloudWatchLogsDev"
        Effect = "Allow"
        Action = "logs:*"
        Resource = "arn:aws:logs:*:*:log-group:*dev*"
      }
    ]
  })

  tags = {
    Environment = "dev"
    Purpose     = "CN group dev environment access"
  }
}

resource "aws_iam_group_policy_attachment" "cn_dev_access" {
  group      = "CN"  # common/existing에서 관리하는 그룹
  policy_arn = aws_iam_policy.cn_dev_access.arn
}

#############################################
# CS 그룹 - Dev 환경 정책 (SecurityAudit)
#############################################

resource "aws_iam_group_policy_attachment" "cs_security_audit" {
  group      = "CS"
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

#############################################
# PM 그룹 - Dev 환경 정책 (CloudWatch 로그 읽기)
#############################################

resource "aws_iam_policy" "pm_dev_access" {
  name        = "PM-Dev-Access"
  description = "PM 그룹의 dev 환경 CloudWatch 로그 읽기 권한"
  path        = "/env/dev/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsRead"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:*dev*"
      }
    ]
  })

  tags = {
    Environment = "dev"
    Purpose     = "PM group dev environment access"
  }
}

resource "aws_iam_group_policy_attachment" "pm_dev_access" {
  group      = "PM"
  policy_arn = aws_iam_policy.pm_dev_access.arn
}
