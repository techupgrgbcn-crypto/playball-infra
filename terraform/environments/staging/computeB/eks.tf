#############################################
# EKS Cluster - Test Account (계정 B)
#############################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.eks_cluster_full_name
  cluster_version = var.eks_cluster_version

  enable_cluster_creator_admin_permissions = true
  iam_role_use_name_prefix                 = false
  iam_role_name                            = local.eks_cluster_iam_role_name

  # VPC
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
  eks_managed_node_groups = {
    # ON_DEMAND (인프라 + 기본 앱)
    on_demand = {
      name           = "${var.owner_name}-on-demand"
      instance_types = var.eks_on_demand_instance_types
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2_ARM_64"

      iam_role_use_name_prefix = false
      iam_role_name            = local.eks_on_demand_iam_role_name

      min_size     = var.eks_on_demand_min_size
      max_size     = var.eks_on_demand_max_size
      desired_size = var.eks_on_demand_desired_size

      labels = {
        "node-type" = "on-demand"
        "workload"  = "infra-and-base"
        "arch"      = "arm64"
        "owner"     = var.owner_name
      }
    }

    # SPOT (앱 스케일링)
    spot = {
      name           = "${var.owner_name}-spot"
      instance_types = var.eks_spot_instance_types
      capacity_type  = "SPOT"
      ami_type       = "AL2_ARM_64"

      iam_role_use_name_prefix = false
      iam_role_name            = local.eks_spot_iam_role_name

      min_size     = var.eks_spot_min_size
      max_size     = var.eks_spot_max_size
      desired_size = var.eks_spot_desired_size

      labels = {
        "node-type" = "spot"
        "workload"  = "app-scaling"
        "arch"      = "arm64"
        "owner"     = var.owner_name
      }

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
    Name = "${var.owner_name}-${var.eks_cluster_name}"
  }
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = local.eks_ebs_csi_irsa_role_name

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Name = "${var.owner_name}-ebs-csi-irsa"
  }
}

#############################################
# EKS Blueprints Addons
#############################################

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16"

  depends_on = [module.eks, module.ebs_csi_driver_irsa]

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  create_delay_duration     = "60s"
  create_delay_dependencies = [for group in module.eks.eks_managed_node_groups : group.node_group_arn]
  observability_tag         = null

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
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
      timeouts = {
        create = "30m"
      }
    }
  }

  # AWS Load Balancer Controller
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    set = [
      {
        name  = "enableServiceMutatorWebhook"
        value = "false"
      }
    ]
  }

  # External Secrets Operator
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
    Name = "${var.owner_name}-eks-addons"
  }
}

#############################################
# ClusterSecretStore (AWS Secrets Manager)
#############################################

resource "kubectl_manifest" "cluster_secret_store" {
  depends_on = [module.eks_blueprints_addons, module.external_secrets_irsa]

  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ClusterSecretStore
    metadata:
      name: aws-secrets-manager
    spec:
      provider:
        aws:
          service: SecretsManager
          region: ${var.aws_region}
          auth:
            jwt:
              serviceAccountRef:
                name: external-secrets
                namespace: external-secrets
  YAML
}

#############################################
# ArgoCD Git Repository Credentials (External Secret)
#############################################

resource "kubectl_manifest" "argocd_repo_external_secret" {
  depends_on = [module.eks_blueprints_addons, kubectl_manifest.cluster_secret_store]

  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: argocd-repo-github-ssh
      namespace: argocd
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: aws-secrets-manager
        kind: ClusterSecretStore
      target:
        name: repo-github-ssh
        template:
          metadata:
            labels:
              argocd.argoproj.io/secret-type: repository
          data:
            url: "git@github.com:goorm-gongbang/303-goormgb-k8s-helm.git"
            type: "git"
            sshPrivateKey: "{{ .sshPrivateKey }}"
      data:
        - secretKey: sshPrivateKey
          remoteRef:
            key: staging/argocd/github-ssh
            property: sshPrivateKey
  YAML
}

#############################################
# ArgoCD Application (App of Apps)
#############################################

resource "kubectl_manifest" "argocd_app_of_apps" {
  depends_on = [module.eks_blueprints_addons, kubectl_manifest.argocd_repo_external_secret]

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
# IRSA for External Secrets
# 테스트 계정(계정 B)의 Secrets Manager 접근
#############################################

module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.owner_name}-${var.eks_cluster_name}-external-secrets"

  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:${var.aws_region}:*:secret:staging/*"]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  tags = {
    Name = "${var.owner_name}-external-secrets-irsa"
  }
}

#############################################
# IRSA for ECR Pull (Cross-Account)
# 메인 계정(계정 A) ECR에서 이미지 Pull
#############################################

resource "aws_iam_policy" "ecr_cross_account_pull" {
  name        = "${var.owner_name}-ecr-cross-account-pull"
  description = "Allow pulling images from main account ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${var.main_account_id}:repository/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# Node Group IAM Role에 ECR Cross-Account Policy 추가
resource "aws_iam_role_policy_attachment" "node_ecr_cross_account" {
  for_each = module.eks.eks_managed_node_groups

  role       = each.value.iam_role_name
  policy_arn = aws_iam_policy.ecr_cross_account_pull.arn
}

# EBS CSI controller가 node IAM role로 fallback 하더라도 필요한 EC2 권한이 있도록 보강
resource "aws_iam_role_policy_attachment" "node_ebs_csi" {
  for_each = module.eks.eks_managed_node_groups

  role       = each.value.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
