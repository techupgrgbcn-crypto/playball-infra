variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

#############################################
# Domain
#############################################

variable "domain_name" {
  description = "Main domain name"
  type        = string
  default     = "playball.one"
}

#############################################
# CloudFront Origins
# NLB DNS를 직접 입력 (computeA or computeB)
#
# 예시: xxxx.elb.ap-northeast-2.amazonaws.com
#
# 확인 방법:
#   kubectl get svc -n istio-system istio-ingressgateway \
#     -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
#############################################

variable "api_nlb_domain" {
  description = "API NLB domain - CloudFront Origin (computeA or computeB의 NLB DNS)"
  type        = string
  default     = "placeholder.elb.ap-northeast-2.amazonaws.com"
  # 확인: kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

  validation {
    condition     = var.api_nlb_domain != "placeholder.elb.ap-northeast-2.amazonaws.com"
    error_message = "api_nlb_domain must be set to a real NLB DNS name in terraform.tfvars"
  }
}

variable "monitoring_nlb_domain" {
  description = "Monitoring NLB domain - CloudFront Origin (computeA or computeB의 NLB DNS)"
  type        = string
  default     = "placeholder.elb.ap-northeast-2.amazonaws.com"

  validation {
    condition     = var.monitoring_nlb_domain != "placeholder.elb.ap-northeast-2.amazonaws.com"
    error_message = "monitoring_nlb_domain must be set to a real NLB DNS name in terraform.tfvars"
  }
}

#############################################
# Cross-Account ECR Access
#############################################

variable "ecr_allowed_account_ids" {
  description = "AWS Account IDs allowed to pull ECR images (테스트 계정 등)"
  type        = list(string)
  default     = []  # terraform.tfvars에서 설정
}
