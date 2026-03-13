#############################################
# EKS Blueprints
#############################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  # VPC (base에서 참조)
  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  # 클러스터 엔드포인트
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.eks_public_access_cidrs

  # 클러스터 로깅
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # OIDC Provider (IRSA용)
  enable_irsa = true

  # 클러스터 보안 그룹 추가 규칙
  cluster_security_group_additional_rules = {
    bastion_ingress = {
      description              = "Bastion to EKS API"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_security_group_id = aws_security_group.bastion.id
    }
  }

  # EKS Managed Node Groups
  # TODO: Graviton (ARM) 사용 시 Docker 이미지를 linux/arm64로 빌드해야 함
  # docker buildx build --platform linux/arm64 -t <image> --push .
  eks_managed_node_groups = {
    # ON_DEMAND (인프라 + 기본 앱) - 1개 고정
    # Staging: 모든 인프라(Istio, ArgoCD, Prometheus 등) + 앱이 여기서 실행
    on_demand = {
      name           = "${var.eks_cluster_name}-on-demand"
      instance_types = var.eks_on_demand_instance_types
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2_ARM_64"  # Graviton (ARM) AMI

      min_size     = var.eks_on_demand_min_size
      max_size     = var.eks_on_demand_max_size
      desired_size = var.eks_on_demand_desired_size

      labels = {
        "node-type" = "on-demand"
        "workload"  = "infra-and-base"
        "arch"      = "arm64"
      }
    }

    # SPOT (앱 스케일링) - 트래픽 증가 시 수평 확장
    # Taint로 인프라 Pod 스케줄링 방지, App Pod만 여기로 스케줄링
    spot = {
      name           = "${var.eks_cluster_name}-spot"
      instance_types = var.eks_spot_instance_types
      capacity_type  = "SPOT"
      ami_type       = "AL2_ARM_64"  # Graviton (ARM) AMI

      min_size     = var.eks_spot_min_size
      max_size     = var.eks_spot_max_size
      desired_size = var.eks_spot_desired_size

      labels = {
        "node-type" = "spot"
        "workload"  = "app-scaling"
        "arch"      = "arm64"
      }

      # SPOT 노드에는 인프라 Pod가 스케줄링되지 않음
      # App Pod에 tolerations 추가 필요:
      # tolerations:
      #   - key: "spot"
      #     operator: "Equal"
      #     value: "true"
      #     effect: "NoSchedule"
      taints = [
        {
          key    = "spot"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

#############################################
# EKS Blueprints Addons
#############################################

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # EKS 기본 Addons
  eks_addons = {
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # AWS Load Balancer Controller (Istio Gateway용 NLB 생성)
  enable_aws_load_balancer_controller = true

  # External Secrets Operator (Secrets Manager 연동)
  enable_external_secrets = true
  external_secrets = {
    namespace = "external-secrets"
  }

  # ArgoCD
  enable_argocd = true
  argocd = {
    namespace = "argocd"
    values    = [file("${path.module}/argocd-values.yaml")]
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

#############################################
# ArgoCD Application (App of Apps)
#############################################

resource "kubectl_manifest" "argocd_app_of_apps" {
  depends_on = [module.eks_blueprints_addons]

  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: staging-root
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: git@github.com:goorm-gongbang/303-goormgb-k8s-helm.git
        targetRevision: argocd-sync/staging
        path: staging/root
      destination:
        server: https://kubernetes.default.svc
        namespace: argocd
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  YAML
}

#############################################
# IRSA for External Secrets (Secrets Manager 접근)
#############################################

module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.eks_cluster_name}-external-secrets"

  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:${var.aws_region}:*:secret:prod/*"]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  tags = {
    Environment = var.environment
  }
}

#############################################
# Outputs
#############################################

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster CA data"
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}
