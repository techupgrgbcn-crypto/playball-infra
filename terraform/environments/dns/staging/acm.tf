#############################################
# ACM Certificate - ap-northeast-2 (ALB/NLB용)
#############################################

resource "aws_acm_certificate" "seoul" {
  domain_name               = "${var.environment}.${var.domain_name}"
  subject_alternative_names = ["*.${var.environment}.${var.domain_name}"]
  validation_method         = "DNS"

  tags = {
    Name        = "${var.environment}.${var.domain_name}-cert"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation_seoul" {
  for_each = {
    for dvo in aws_acm_certificate.seoul.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.this.zone_id
}

resource "aws_acm_certificate_validation" "seoul" {
  certificate_arn         = aws_acm_certificate.seoul.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_seoul : record.fqdn]
}

#############################################
# ACM Certificate - us-east-1 (CloudFront용)
#############################################

resource "aws_acm_certificate" "cloudfront" {
  provider = aws.us_east_1

  domain_name               = "${var.environment}.${var.domain_name}"
  subject_alternative_names = ["*.${var.environment}.${var.domain_name}"]
  validation_method         = "DNS"

  tags = {
    Name        = "${var.environment}.${var.domain_name}-cloudfront-cert"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation_cloudfront" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.this.zone_id
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_cloudfront : record.fqdn]
}
