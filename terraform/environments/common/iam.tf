#############################################
# Account Alias
#############################################

resource "aws_iam_account_alias" "alias" {
  account_alias = "goormgb"
}

#############################################
# Account Password Policy
#############################################

resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 12
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 5
}

#############################################
# IAM Groups - 신규
#############################################

# CS (Cyber Security) - 보안팀
resource "aws_iam_group" "cs" {
  name = "CS"
  path = "/teams/"
}

# DEV (Developers) - 개발팀
# ABAC: team 태그로 세분화 (frontend, backend, ai)
resource "aws_iam_group" "dev" {
  name = "DEV"
  path = "/teams/"
}

# PM (Project Managers) - 기획팀
resource "aws_iam_group" "pm" {
  name = "PM"
  path = "/teams/"
}

#############################################
# IAM Users - CS (Cyber Security) - 신규
#############################################

locals {
  cs_members = {
    min   = {}
    wan   = {}
    jiseo = {}
  }
}

resource "aws_iam_user" "cs" {
  for_each = local.cs_members

  name = each.key
  path = "/teams/cs/"

  tags = {
    Team = "CS"
  }
}

resource "aws_iam_group_membership" "cs" {
  name  = "cs-membership"
  group = aws_iam_group.cs.name
  users = [for user in aws_iam_user.cs : user.name]
}

#############################################
# IAM Users - DEV (Developers) - 신규
# ABAC: team 태그로 접근 권한 분리 예정
# - frontend: S3 assets, CloudFront
# - backend: RDS, ElastiCache, SQS
# - ai: SageMaker, Bedrock, S3 ml-data
#############################################

locals {
  dev_members = {
    seul   = { team = "backend" }
    si     = { team = "backend" }
    eui    = { team = "backend" }
    kw     = { team = "frontend" }
    dong   = { team = "ai" }
    jihyeoniu = { team = "ai" }
  }
}

resource "aws_iam_user" "dev" {
  for_each = local.dev_members

  name = each.key
  path = "/teams/dev/"

  tags = {
    Team    = "DEV"
    SubTeam = each.value.team  # ABAC용 태그
  }
}

resource "aws_iam_group_membership" "dev" {
  name  = "dev-membership"
  group = aws_iam_group.dev.name
  users = [for user in aws_iam_user.dev : user.name]
}

#############################################
# IAM Users - PM (Project Managers) - 신규
#############################################

locals {
  pm_members = {
    jehyun = {}
  }
}

resource "aws_iam_user" "pm" {
  for_each = local.pm_members

  name = each.key
  path = "/teams/pm/"

  tags = {
    Team = "PM"
  }
}

resource "aws_iam_group_membership" "pm" {
  name  = "pm-membership"
  group = aws_iam_group.pm.name
  users = [for user in aws_iam_user.pm : user.name]
}

#############################################
# MFA 강제 정책 (공통)
#############################################

resource "aws_iam_policy" "force_mfa" {
  name        = "ForceMFA"
  description = "MFA 활성화 강제 - MFA 없이는 자기 자신의 보안 설정만 가능"
  path        = "/security/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowViewAccountInfo"
        Effect = "Allow"
        Action = [
          "iam:GetAccountPasswordPolicy",
          "iam:ListVirtualMFADevices",
          "iam:ListMFADevices",
          "iam:GetMFADevice"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowManageOwnVirtualMFADevice"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice",
          "iam:DeleteVirtualMFADevice"
        ]
        Resource = "arn:aws:iam::*:mfa/$${aws:username}"
      },
      {
        Sid    = "AllowManageOwnMFA"
        Effect = "Allow"
        Action = [
          "iam:DeactivateMFADevice",
          "iam:EnableMFADevice",
          "iam:ListMFADevices",
          "iam:ResyncMFADevice"
        ]
        Resource = "arn:aws:iam::*:user/*/$${aws:username}"
      },
      {
        Sid    = "AllowChangeOwnPassword"
        Effect = "Allow"
        Action = [
          "iam:ChangePassword",
          "iam:GetUser"
        ]
        Resource = "arn:aws:iam::*:user/*/$${aws:username}"
      },
      {
        Sid    = "AllowManageOwnSecurityCredentials"
        Effect = "Allow"
        Action = [
          "iam:ListAccessKeys",
          "iam:CreateAccessKey",
          "iam:DeleteAccessKey",
          "iam:UpdateAccessKey",
          "iam:ListSigningCertificates",
          "iam:ListSSHPublicKeys",
          "iam:ListServiceSpecificCredentials",
          "iam:GetLoginProfile"
        ]
        Resource = "arn:aws:iam::*:user/*/$${aws:username}"
      },
      {
        Sid    = "DenyAllExceptListedIfNoMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:GetMFADevice",
          "iam:ResyncMFADevice",
          "iam:ChangePassword",
          "iam:GetAccountPasswordPolicy",
          "iam:ListAccessKeys",
          "iam:ListSigningCertificates",
          "iam:ListSSHPublicKeys",
          "iam:ListServiceSpecificCredentials",
          "iam:GetLoginProfile",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })

  tags = {
    Purpose = "MFA Enforcement"
  }
}

resource "aws_iam_group_policy_attachment" "cs_force_mfa" {
  group      = aws_iam_group.cs.name
  policy_arn = aws_iam_policy.force_mfa.arn
}

resource "aws_iam_group_policy_attachment" "dev_force_mfa" {
  group      = aws_iam_group.dev.name
  policy_arn = aws_iam_policy.force_mfa.arn
}

resource "aws_iam_group_policy_attachment" "pm_force_mfa" {
  group      = aws_iam_group.pm.name
  policy_arn = aws_iam_policy.force_mfa.arn
}

#############################################
# Billing 읽기 권한 (모든 그룹 공통)
#############################################

resource "aws_iam_group_policy_attachment" "cs_billing" {
  group      = aws_iam_group.cs.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}

resource "aws_iam_group_policy_attachment" "dev_billing" {
  group      = aws_iam_group.dev.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}

resource "aws_iam_group_policy_attachment" "pm_billing" {
  group      = aws_iam_group.pm.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}

#############################################
# Cost Explorer 읽기 권한 (모든 그룹 공통)
#############################################

resource "aws_iam_policy" "cost_explorer_read" {
  name        = "CostExplorerReadOnly"
  description = "Cost Explorer 및 Cost Management 콘솔 읽기 권한"
  path        = "/common/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CostExplorerReadAccess"
        Effect = "Allow"
        Action = [
          "ce:Describe*",
          "ce:Get*",
          "ce:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CostAndUsageReportReadAccess"
        Effect = "Allow"
        Action = [
          "cur:DescribeReportDefinitions",
          "cur:GetClassicReport",
          "cur:GetClassicReportPreferences",
          "cur:GetUsageReport"
        ]
        Resource = "*"
      },
      {
        Sid    = "CostOptimizationHubReadAccess"
        Effect = "Allow"
        Action = [
          "cost-optimization-hub:Get*",
          "cost-optimization-hub:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "SavingsPlansReadAccess"
        Effect = "Allow"
        Action = [
          "savingsplans:Describe*",
          "savingsplans:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ComputeOptimizerReadAccess"
        Effect = "Allow"
        Action = [
          "compute-optimizer:Get*",
          "compute-optimizer:Describe*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Purpose = "Cost Explorer read access for all groups"
  }
}

# Cost Explorer 정책을 모든 그룹에 연결 (for_each로 통합)
resource "aws_iam_group_policy_attachment" "cost_explorer" {
  for_each = toset([
    aws_iam_group.cs.name,
    aws_iam_group.dev.name,
    aws_iam_group.pm.name,
    aws_iam_group.cn.name
  ])

  group      = each.key
  policy_arn = aws_iam_policy.cost_explorer_read.arn
}

#############################################
# PM 그룹 추가 권한 (계정/빌링 정보 조회)
#############################################

resource "aws_iam_policy" "pm_account_billing" {
  name        = "PM-Account-Billing-Access"
  description = "PM 그룹 계정 및 빌링 정보 조회 권한"
  path        = "/teams/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AccountInfo"
        Effect = "Allow"
        Action = [
          "account:GetAccountInformation",
          "account:GetPrimaryEmail",
          "account:GetContactInformation"
        ]
        Resource = "*"
      },
      {
        Sid    = "BillingInfo"
        Effect = "Allow"
        Action = [
          "billing:GetSellerOfRecord",
          "billing:GetBillingData",
          "billing:GetBillingDetails",
          "billing:GetBillingNotifications",
          "billing:GetBillingPreferences"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Purpose = "PM group account and billing access"
  }
}

resource "aws_iam_group_policy_attachment" "pm_account_billing" {
  group      = aws_iam_group.pm.name
  policy_arn = aws_iam_policy.pm_account_billing.arn
}

#############################################
# IAM User Login Profiles (콘솔 로그인용)
# 첫 로그인 시 비밀번호 변경 강제
#############################################

# 초기 비밀번호는 terraform apply 후 아래 명령어로 설정:
# aws iam create-login-profile --user-name <USER> --password "<STRONG_TEMP_PASSWORD>" --password-reset-required
#
# 또는 전체 유저 일괄 설정 스크립트:
# for user in min wan jiseo seul si eui kw dong jihyun hyun; do
#   aws iam create-login-profile --user-name $user --password "<STRONG_TEMP_PASSWORD>" --password-reset-required
# done
#
# 주의: 임시 비밀번호는 안전한 채널을 통해 사용자에게 전달하세요.

#############################################
# IAM Group: CN (Cloud Native)
#############################################

resource "aws_iam_group" "cn" {
  name = "CN"
  path = "/teams/"
}

locals {
  cn_members = {
    ash      = {}
    "7eehy3" = {}
    wonny    = {}
  }
}

resource "aws_iam_user" "cn" {
  for_each = local.cn_members

  name = each.key
  path = "/teams/cn/"

  tags = {
    Team = "CN"
  }
}

resource "aws_iam_group_membership" "cn" {
  name  = "cn-membership"
  group = aws_iam_group.cn.name
  users = [for user in aws_iam_user.cn : user.name]
}

resource "aws_iam_group_policy_attachment" "cn_billing" {
  group      = aws_iam_group.cn.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}

# cn_cost_explorer는 위의 for_each에서 처리됨

resource "aws_iam_group_policy_attachment" "cn_force_mfa" {
  group      = aws_iam_group.cn.name
  policy_arn = aws_iam_policy.force_mfa.arn
}

# CN 그룹 IAM 권한 (나중에 필요시 제거 가능)
resource "aws_iam_group_policy_attachment" "cn_iam" {
  group      = aws_iam_group.cn.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

#############################################
# CN 그룹 - 공통 조회 권한 (S3, ECR 목록)
#############################################

resource "aws_iam_policy" "cn_common_access" {
  name        = "CN-Common-Access"
  description = "CN 그룹 공통 리소스 접근 권한"
  path        = "/teams/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 - 버킷 목록 조회
      {
        Sid    = "S3ListAllBuckets"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      },
      # S3 - goormgb-assets Full Access
      {
        Sid    = "S3AssetsFullAccess"
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::goormgb-assets",
          "arn:aws:s3:::goormgb-assets/*"
        ]
      },
      # S3 - goormgb-tf-state Full Access
      # TODO: 나중에 GitHub Actions OIDC로 전환 시 CN 권한 ReadOnly로 변경
      {
        Sid    = "S3TfStateFullAccess"
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::goormgb-tf-state",
          "arn:aws:s3:::goormgb-tf-state/*"
        ]
      },
      # S3 - goormgb-backup Full Access
      {
        Sid    = "S3BackupFullAccess"
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::goormgb-backup",
          "arn:aws:s3:::goormgb-backup/*"
        ]
      },
      # S3 - goormgb-ai-data Full Access
      {
        Sid    = "S3AiDataFullAccess"
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::goormgb-ai-data",
          "arn:aws:s3:::goormgb-ai-data/*"
        ]
      },
      # S3 - goormgb-ai-backup Full Access
      {
        Sid    = "S3AiBackupFullAccess"
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::goormgb-ai-backup",
          "arn:aws:s3:::goormgb-ai-backup/*"
        ]
      },
      # DynamoDB - Terraform Lock
      # TODO: 나중에 GitHub Actions OIDC로 전환 시 CN 권한 ReadOnly로 변경
      {
        Sid    = "DynamoDBTfLock"
        Effect = "Allow"
        Action = "dynamodb:*"
        Resource = "arn:aws:dynamodb:*:*:table/goormgb-tf-lock"
      },
      # ECR - 목록 조회
      {
        Sid    = "ECRListRepositories"
        Effect = "Allow"
        Action = [
          "ecr:DescribeRepositories",
          "ecr:DescribeRegistry",
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      # Secrets Manager - 목록 조회
      {
        Sid    = "SecretsManagerList"
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Purpose = "CN group common access"
  }
}

resource "aws_iam_group_policy_attachment" "cn_common_access" {
  group      = aws_iam_group.cn.name
  policy_arn = aws_iam_policy.cn_common_access.arn
}

#############################################
# IAM Group: CICD Bots
#############################################

resource "aws_iam_group" "cicd_bots" {
  name = "CICD-Bots-Group"
  path = "/system/"
}

resource "aws_iam_user" "bot_teamcity" {
  name = "bot-teamcity"
  path = "/system/"

  tags = {
    Purpose = "TeamCity CI/CD"
  }
}

resource "aws_iam_user" "bot_argocd" {
  name = "bot-argocd"
  path = "/system/"

  tags = {
    Purpose = "ArgoCD GitOps"
  }
}

resource "aws_iam_user" "bot_kubeadm" {
  name = "bot-kubeadm"
  path = "/system/"

  tags = {
    Purpose = "Kubeadm K8s Backup"
  }
}

resource "aws_iam_group_membership" "cicd_bots" {
  name  = "cicd-bots-membership"
  group = aws_iam_group.cicd_bots.name
  users = [
    aws_iam_user.bot_teamcity.name,
    aws_iam_user.bot_argocd.name
  ]
}

resource "aws_iam_group_policy_attachment" "cicd_bots_ecr" {
  group      = aws_iam_group.cicd_bots.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

#############################################
# IAM Group: temp (mighty 사용자용)
#############################################

resource "aws_iam_group" "temp" {
  name = "temp"
  path = "/"
}

resource "aws_iam_user" "mighty" {
  name = "mighty"
  path = "/"

  tags = {
    Purpose = "Temporary Admin"
  }
}

resource "aws_iam_group_membership" "temp" {
  name  = "temp-membership"
  group = aws_iam_group.temp.name
  users = [aws_iam_user.mighty.name]
}

#############################################
# IAM Policy: bot-kubeadm Dev Access
#############################################

resource "aws_iam_policy" "bot_kubeadm_dev" {
  name        = "bot-kubeadm-dev-access"
  description = "bot-kubeadm access for dev environment backup and secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BackupAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::goormgb-backup/dev/*"
      },
      {
        Sid    = "S3ListBucket"
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = "arn:aws:s3:::goormgb-backup"
        Condition = {
          StringLike = {
            "s3:prefix" = ["dev/*"]
          }
        }
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:dev/*"
      },
      {
        Sid    = "ECRAuthToken"
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPullAccess"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:ap-northeast-2:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "bot_kubeadm_dev" {
  user       = aws_iam_user.bot_kubeadm.name
  policy_arn = aws_iam_policy.bot_kubeadm_dev.arn
}

# #############################################
# # GitHub Actions OIDC Provider (미사용 - 주석처리)
# # TeamCity로 CI/CD 운영 중, 필요시 주석 해제
# #############################################
#
# data "tls_certificate" "github_actions" {
#   url = "https://token.actions.githubusercontent.com"
# }
#
# resource "aws_iam_openid_connect_provider" "github_actions" {
#   url = "https://token.actions.githubusercontent.com"
#
#   client_id_list = ["sts.amazonaws.com"]
#
#   thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
#
#   tags = {
#     Name = "GitHub Actions OIDC"
#   }
# }
#
# #############################################
# # GitHub Actions IAM Role
# #############################################
#
# data "aws_iam_policy_document" "github_actions_assume_role" {
#   statement {
#     effect  = "Allow"
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#
#     principals {
#       type        = "Federated"
#       identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
#     }
#
#     condition {
#       test     = "StringEquals"
#       variable = "token.actions.githubusercontent.com:aud"
#       values   = ["sts.amazonaws.com"]
#     }
#
#     condition {
#       test     = "StringLike"
#       variable = "token.actions.githubusercontent.com:sub"
#       values   = [
#         "repo:goorm-gongbang/101-goormgb-frontend:*",
#         "repo:goorm-gongbang/102-goormgb-backend:*",
#         "repo:goorm-gongbang/301-goormgb-terraform:*",
#         "repo:goorm-gongbang/302-goormgb-k8s-bootstrap:*",
#         "repo:goorm-gongbang/303-goormgb-k8s-helm:*"
#       ]
#     }
#   }
# }
#
# resource "aws_iam_role" "github_actions" {
#   name               = "github-actions-role"
#   assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
#
#   tags = {
#     Name = "GitHub Actions Role"
#   }
# }
#
# resource "aws_iam_policy" "github_actions" {
#   name        = "github-actions-policy"
#   description = "Policy for GitHub Actions CI/CD"
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "ECRAuth"
#         Effect = "Allow"
#         Action = "ecr:GetAuthorizationToken"
#         Resource = "*"
#       },
#       {
#         Sid    = "ECRAccess"
#         Effect = "Allow"
#         Action = [
#           "ecr:BatchCheckLayerAvailability",
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:BatchGetImage",
#           "ecr:PutImage",
#           "ecr:InitiateLayerUpload",
#           "ecr:UploadLayerPart",
#           "ecr:CompleteLayerUpload",
#           "ecr:DescribeRepositories",
#           "ecr:ListImages"
#         ]
#         Resource = [
#           "arn:aws:ecr:ap-northeast-2:${data.aws_caller_identity.current.account_id}:repository/dev/goormgb/*",
#           "arn:aws:ecr:ap-northeast-2:${data.aws_caller_identity.current.account_id}:repository/staging/playball/*",
#           "arn:aws:ecr:ap-northeast-2:${data.aws_caller_identity.current.account_id}:repository/prod/playball/*"
#         ]
#       },
#       {
#         Sid    = "S3TerraformState"
#         Effect = "Allow"
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:DeleteObject",
#           "s3:ListBucket"
#         ]
#         Resource = [
#           "arn:aws:s3:::${var.project_name}-tf-state",
#           "arn:aws:s3:::${var.project_name}-tf-state/*"
#         ]
#       },
#       {
#         Sid    = "DynamoDBTerraformLock"
#         Effect = "Allow"
#         Action = [
#           "dynamodb:GetItem",
#           "dynamodb:PutItem",
#           "dynamodb:DeleteItem"
#         ]
#         Resource = "arn:aws:dynamodb:ap-northeast-2:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-tf-lock"
#       },
#       {
#         Sid    = "SecretsManagerRead"
#         Effect = "Allow"
#         Action = [
#           "secretsmanager:GetSecretValue",
#           "secretsmanager:DescribeSecret"
#         ]
#         Resource = [
#           "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:dev/*",
#           "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:staging/*"
#         ]
#       }
#     ]
#   })
# }
#
# resource "aws_iam_role_policy_attachment" "github_actions" {
#   role       = aws_iam_role.github_actions.name
#   policy_arn = aws_iam_policy.github_actions.arn
# }
