#############################################
# Data Sources - dns/staging에서 관리하는 리소스 참조
#############################################

data "aws_caller_identity" "current" {}

# Route53 Zone (dns/staging에서 관리)
data "aws_route53_zone" "staging" {
  name = "${var.environment}.${var.domain_name}"
}

# ACM Certificate - Seoul (dns/staging에서 관리)
data "aws_acm_certificate" "staging_seoul" {
  domain      = "${var.environment}.${var.domain_name}"
  statuses    = ["ISSUED"]
  most_recent = true
}

# ACM Certificate - CloudFront (dns/staging에서 관리)
data "aws_acm_certificate" "staging_cloudfront" {
  provider    = aws.us_east_1
  domain      = "${var.environment}.${var.domain_name}"
  statuses    = ["ISSUED"]
  most_recent = true
}
