#############################################
# ECR Repositories for Helm Charts (OCI)
#############################################

locals {
  # ECR 리포지토리 이름은 실제 Helm 차트 이름과 동일해야 함
  helm_charts = [
    "base",              # istio-base 차트
    "istiod",            # istio control plane
    "kiali-server",      # kiali
    "external-secrets",
    "tigera-operator",
    "loki",
    "promtail",
    "alloy",
    "k6-operator",
    "kube-prometheus-stack",
    "tempo",                    # Grafana Tempo (distributed tracing)
    "opentelemetry-collector",  # OpenTelemetry Collector
  ]
}

resource "aws_ecr_repository" "helm_charts" {
  for_each = toset(local.helm_charts)

  name                 = "helm/${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "helm-${each.key}"
    Type = "helm-chart"
  }
}

#############################################
# ECR Lifecycle Policy (optional)
#############################################

resource "aws_ecr_lifecycle_policy" "helm_charts" {
  for_each = aws_ecr_repository.helm_charts

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 versions"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

#############################################
# Outputs
#############################################

output "helm_ecr_repositories" {
  description = "Helm chart ECR repository URLs"
  value = {
    for name, repo in aws_ecr_repository.helm_charts :
    name => repo.repository_url
  }
}
