#############################################
# Route53 Records - Compute 레이어
# (compute 리소스에 의존하는 레코드들)
#############################################

# Bastion - EIP로 연결
resource "aws_route53_record" "bastion_staging" {
  zone_id = local.staging_zone_id
  name    = "bastion"  # bastion.staging.playball.one
  type    = "A"
  ttl     = 300
  records = [aws_eip.bastion.public_ip]
}

#############################################
# Note: NLB DNS 레코드
# api-nlb, monitoring-nlb 레코드는 Istio IngressGateway가
# 생성하는 NLB를 참조해야 함
#
# 방법 1: ExternalDNS 사용 (권장)
# 방법 2: NLB 생성 후 data source로 참조
#
# ExternalDNS가 설치되면 Kubernetes Service annotation으로
# DNS 레코드가 자동 생성됨
#############################################
