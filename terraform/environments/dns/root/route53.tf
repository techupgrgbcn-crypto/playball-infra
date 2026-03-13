#############################################
# Route53 Hosted Zone - playball.one (루트)
#############################################

resource "aws_route53_zone" "root" {
  name = var.domain_name

  tags = {
    Name        = var.domain_name
    Environment = "shared"
  }
}

#############################################
# NS Delegation - Subdomain Zones
#############################################

# staging.playball.one NS 위임
resource "aws_route53_record" "staging_ns" {
  count = length(var.staging_zone_name_servers) > 0 ? 1 : 0

  zone_id = aws_route53_zone.root.zone_id
  name    = "staging"
  type    = "NS"
  ttl     = 300
  records = var.staging_zone_name_servers
}

# prod.playball.one NS 위임 (나중에 사용)
resource "aws_route53_record" "prod_ns" {
  count = length(var.prod_zone_name_servers) > 0 ? 1 : 0

  zone_id = aws_route53_zone.root.zone_id
  name    = "prod"
  type    = "NS"
  ttl     = 300
  records = var.prod_zone_name_servers
}

#############################################
# Porkbun에 설정할 NS 레코드 출력
#############################################
# 이 NS 레코드들을 Porkbun DNS 설정에 추가해야 함
# Type: NS, Host: @, Answer: (각 name server)
