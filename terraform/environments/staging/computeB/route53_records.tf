#############################################
# Route53 Records - ComputeB
# 메인 계정(A)의 Route53에 레코드 생성
#
# ExternalDNS 대신 Terraform으로 관리하는 경우 사용
# ExternalDNS 사용시 이 파일의 리소스를 주석 처리
#############################################

#############################################
# Variables for Route53
#############################################

variable "staging_zone_id" {
  description = "Route53 Zone ID for staging.playball.one (메인 계정)"
  type        = string
  default     = "" # terraform.tfvars에서 설정 또는 ExternalDNS 사용
}

variable "manage_route53_records" {
  description = "Terraform으로 Route53 레코드 관리 여부 (false면 ExternalDNS 사용)"
  type        = bool
  default     = false
}

#############################################
# NLB DNS Records (CloudFront Origin용)
#
# Istio IngressGateway가 생성하는 NLB를 참조
# EKS 배포 후 NLB DNS를 확인하여 data source로 참조
#############################################

# Istio가 생성한 NLB 조회 (EKS 배포 후 활성화)
# data "aws_lb" "istio_nlb" {
#   tags = {
#     "kubernetes.io/service-name" = "istio-system/istio-ingressgateway"
#   }
#   depends_on = [module.eks_blueprints_addons]
# }

# API NLB - CloudFront가 참조하는 Origin
# resource "aws_route53_record" "api_nlb" {
#   count    = var.manage_route53_records && var.staging_zone_id != "" ? 1 : 0
#   provider = aws.main_account
#
#   zone_id = var.staging_zone_id
#   name    = "api-nlb"  # api-nlb.staging.playball.one
#   type    = "CNAME"
#   ttl     = 300
#   records = [data.aws_lb.istio_nlb.dns_name]
# }

# Monitoring NLB - CloudFront가 참조하는 Origin
# resource "aws_route53_record" "monitoring_nlb" {
#   count    = var.manage_route53_records && var.staging_zone_id != "" ? 1 : 0
#   provider = aws.main_account
#
#   zone_id = var.staging_zone_id
#   name    = "monitoring-nlb"  # monitoring-nlb.staging.playball.one
#   type    = "CNAME"
#   ttl     = 300
#   records = [data.aws_lb.istio_nlb.dns_name]
# }

#############################################
# Bastion Record
#############################################

resource "aws_route53_record" "bastion" {
  count    = var.manage_route53_records && var.staging_zone_id != "" ? 1 : 0
  provider = aws.main_account

  zone_id = var.staging_zone_id
  name    = "bastion-b" # bastion-b.staging.playball.one (computeB용)
  type    = "A"
  ttl     = 300
  records = [aws_eip.bastion.public_ip]
}

#############################################
# ExternalDNS 사용 가이드
#############################################
#
# ExternalDNS가 Cross-Account Route53에 접근하려면:
#
# 1. 메인 계정(A)에 IAM Role 생성:
#    - Trust: 테스트 계정(B)의 ExternalDNS IRSA Role
#    - Policy: route53:ChangeResourceRecordSets, route53:ListHostedZones
#
# 2. ExternalDNS Helm values 설정:
#    provider: aws
#    aws:
#      assumeRoleArn: arn:aws:iam::MAIN_ACCOUNT_ID:role/ExternalDNS-CrossAccount
#      region: ap-northeast-2
#    domainFilters:
#      - staging.playball.one
#    txtOwnerId: computeB
#
# 3. Istio Gateway Service annotation:
#    external-dns.alpha.kubernetes.io/hostname: api-nlb.staging.playball.one
#
#############################################
