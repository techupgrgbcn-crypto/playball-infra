#############################################
# ECR Repositories - Staging
# 네이밍: staging/playball/{web|ai}/{서비스}
#############################################

locals {
  ecr_web_services = [
    "api-gateway",
    "auth-guard",
    "order-core",
    "queue",
    "recommendation",
    "seat"
  ]

  ecr_ai_services = [
    "defense",
    "authz-adapter"
  ]
}

# Web Services
resource "aws_ecr_repository" "web" {
  for_each = toset(local.ecr_web_services)

  name                 = "staging/playball/web/${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name        = "staging/playball/web/${each.key}"
    Service     = each.key
    Type        = "web"
    Environment = "staging"
  }
}

# AI Services
resource "aws_ecr_repository" "ai" {
  for_each = toset(local.ecr_ai_services)

  name                 = "staging/playball/ai/${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name        = "staging/playball/ai/${each.key}"
    Service     = each.key
    Type        = "ai"
    Environment = "staging"
  }
}

#############################################
# ECR Lifecycle Policy
#############################################

resource "aws_ecr_lifecycle_policy" "web" {
  for_each = toset(local.ecr_web_services)

  repository = aws_ecr_repository.web[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "최근 20개의 이미지만 유지"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "ai" {
  for_each = toset(local.ecr_ai_services)

  repository = aws_ecr_repository.ai[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "최근 20개의 이미지만 유지"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

#############################################
# ECR Cross-Account Repository Policy
# 테스트 계정(계정 B)에서 이미지 Pull 허용
#############################################

locals {
  ecr_cross_account_policy = length(var.ecr_allowed_account_ids) > 0 ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = [for account_id in var.ecr_allowed_account_ids : "arn:aws:iam::${account_id}:root"]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  }) : null
}

# Web Services - Cross-Account Policy
resource "aws_ecr_repository_policy" "web_cross_account" {
  for_each = length(var.ecr_allowed_account_ids) > 0 ? toset(local.ecr_web_services) : toset([])

  repository = aws_ecr_repository.web[each.key].name
  policy     = local.ecr_cross_account_policy
}

# AI Services - Cross-Account Policy
resource "aws_ecr_repository_policy" "ai_cross_account" {
  for_each = length(var.ecr_allowed_account_ids) > 0 ? toset(local.ecr_ai_services) : toset([])

  repository = aws_ecr_repository.ai[each.key].name
  policy     = local.ecr_cross_account_policy
}
