#############################################
# CN 그룹 - Staging 환경 정책
#############################################

resource "aws_iam_policy" "cn_staging_access" {
  name        = "CN-Staging-Access"
  description = "CN 그룹의 staging 환경 접근 권한"
  path        = "/env/staging/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 - staging 백업 prefix Full Access
      {
        Sid    = "S3StagingBackupObjects"
        Effect = "Allow"
        Action = "s3:*"
        Resource = "arn:aws:s3:::goormgb-backup/staging/*"
      },
      {
        Sid    = "S3StagingBackupList"
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = "arn:aws:s3:::goormgb-backup"
        Condition = {
          StringLike = {
            "s3:prefix" = ["staging/*"]
          }
        }
      },
      # Secrets Manager - staging 시크릿 Full Access
      {
        Sid    = "SecretsManagerStaging"
        Effect = "Allow"
        Action = "secretsmanager:*"
        Resource = "arn:aws:secretsmanager:*:*:secret:staging/*"
      },
      # ECR - staging 리포지토리 Full Access
      # (목록 조회는 common/CN-Common-Access에서 처리)
      {
        Sid    = "ECRStagingFull"
        Effect = "Allow"
        Action = "ecr:*"
        Resource = "arn:aws:ecr:*:*:repository/staging/playball/*"
      },
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      # EKS - staging 클러스터
      {
        Sid    = "EKSStagingAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup",
          "eks:ListAddons",
          "eks:DescribeAddon"
        ]
        Resource = "arn:aws:eks:*:*:cluster/goormgb-staging"
      },
      # RDS - staging PostgreSQL
      {
        Sid    = "RDSStagingAccess"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:DescribeDBSnapshots",
          "rds:ListTagsForResource",
          "rds:DescribeDBLogFiles",
          "rds:DownloadDBLogFilePortion",
          "rds:DescribeDBParameters",
          "rds:DescribeDBSubnetGroups",
          "rds:ModifyDBInstance",
          "rds:RebootDBInstance",
          "rds:CreateDBSnapshot",
          "rds:RestoreDBInstanceFromDBSnapshot"
        ]
        Resource = [
          "arn:aws:rds:*:*:db:staging-*",
          "arn:aws:rds:*:*:snapshot:staging-*",
          "arn:aws:rds:*:*:subgrp:staging-*",
          "arn:aws:rds:*:*:pg:staging-*"
        ]
      },
      # ElastiCache - staging Redis
      {
        Sid    = "ElastiCacheStagingAccess"
        Effect = "Allow"
        Action = [
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeReplicationGroups",
          "elasticache:DescribeCacheSubnetGroups",
          "elasticache:DescribeCacheParameterGroups",
          "elasticache:ListTagsForResource",
          "elasticache:ModifyCacheCluster",
          "elasticache:RebootCacheCluster",
          "elasticache:CreateSnapshot",
          "elasticache:DescribeSnapshots"
        ]
        Resource = [
          "arn:aws:elasticache:*:*:cluster:staging-*",
          "arn:aws:elasticache:*:*:replicationgroup:staging-*",
          "arn:aws:elasticache:*:*:subnetgroup:staging-*",
          "arn:aws:elasticache:*:*:parametergroup:staging-*",
          "arn:aws:elasticache:*:*:snapshot:staging-*"
        ]
      },
      # CloudWatch Logs - staging 로그
      {
        Sid    = "CloudWatchLogsStaging"
        Effect = "Allow"
        Action = "logs:*"
        Resource = [
          "arn:aws:logs:*:*:log-group:*staging*",
          "arn:aws:logs:*:*:log-group:/aws/eks/goormgb-staging/*"
        ]
      },
      # CloudWatch Metrics - staging 모니터링
      {
        Sid    = "CloudWatchMetricsStaging"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms"
        ]
        Resource = "*"
      },
      # VPC/EC2 - staging 환경 조회/관리
      {
        Sid    = "VPCStagingAccess"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = "staging"
    Purpose     = "CN group staging environment access"
  }
}

resource "aws_iam_group_policy_attachment" "cn_staging_access" {
  group      = "CN"  # common에서 관리하는 그룹
  policy_arn = aws_iam_policy.cn_staging_access.arn
}
