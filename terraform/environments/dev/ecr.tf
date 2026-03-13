#############################################
# ECR Repositories - Dev
# 기존 AWS 리소스 import용 (dev/goormgb/{서비스})
#############################################

locals {
  # Dev는 기존 네이밍 유지 (web/ai 구분 없음)
  ecr_services = [
    "ai",
    "api-gateway",
    "auth-guard",
    "authz-adapter",  # AI Defense ext_authz Adapter
    "order-core",
    "queue",
    "recommendation",
    "seat"
  ]
}

# All Services (기존 AWS 리소스에 맞춤)
resource "aws_ecr_repository" "service" {
  for_each = toset(local.ecr_services)

  name                 = "dev/goormgb/${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name        = "dev/goormgb/${each.key}"
    Service     = each.key
    Environment = "dev"
  }
}

#############################################
# ECR Lifecycle Policy
#############################################

resource "aws_ecr_lifecycle_policy" "service" {
  for_each = toset(local.ecr_services)

  repository = aws_ecr_repository.service[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "최근 50개의 이미지만 유지"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 50
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
