#############################################
# ACM Certificate - us-east-1 (CloudFront용)
# *.playball.one 와일드카드 인증서
# enable_acm = true 일 때만 생성
#############################################

resource "aws_acm_certificate" "wildcard_cloudfront" {
  count    = var.enable_acm ? 1 : 0
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = {
    Name        = "${var.domain_name}-wildcard-cloudfront"
    Environment = "shared"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# DNS 검증 레코드
resource "aws_route53_record" "wildcard_cert_validation" {
  for_each = var.enable_acm ? {
    for dvo in aws_acm_certificate.wildcard_cloudfront[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.root.zone_id
}

# 인증서 검증 완료 대기
resource "aws_acm_certificate_validation" "wildcard_cloudfront" {
  count    = var.enable_acm ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.wildcard_cloudfront[0].arn
  validation_record_fqdns = [for record in aws_route53_record.wildcard_cert_validation : record.fqdn]
}

#############################################
# ACM Certificate - ap-northeast-2 (ALB/NLB용)
# 필요시 사용
#############################################

resource "aws_acm_certificate" "wildcard_seoul" {
  count = var.enable_acm ? 1 : 0

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = {
    Name        = "${var.domain_name}-wildcard-seoul"
    Environment = "shared"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "wildcard_cert_validation_seoul" {
  for_each = var.enable_acm ? {
    for dvo in aws_acm_certificate.wildcard_seoul[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.root.zone_id
}

resource "aws_acm_certificate_validation" "wildcard_seoul" {
  count = var.enable_acm ? 1 : 0

  certificate_arn         = aws_acm_certificate.wildcard_seoul[0].arn
  validation_record_fqdns = [for record in aws_route53_record.wildcard_cert_validation_seoul : record.fqdn]
}
