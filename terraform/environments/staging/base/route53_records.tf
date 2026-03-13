#############################################
# Route53 Records - Staging 환경
# staging.playball.one zone 내 레코드들
#############################################

# API - CloudFront로 연결
resource "aws_route53_record" "api_staging" {
  zone_id = data.aws_route53_zone.staging.zone_id
  name    = "api"  # api.staging.playball.one
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.api.domain_name
    zone_id                = aws_cloudfront_distribution.api.hosted_zone_id
    evaluate_target_health = false
  }
}

# Grafana - CloudFront로 연결
resource "aws_route53_record" "grafana_staging" {
  zone_id = data.aws_route53_zone.staging.zone_id
  name    = "grafana"  # grafana.staging.playball.one
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.monitoring.domain_name
    zone_id                = aws_cloudfront_distribution.monitoring.hosted_zone_id
    evaluate_target_health = false
  }
}

# ArgoCD - CloudFront로 연결
resource "aws_route53_record" "argocd_staging" {
  zone_id = data.aws_route53_zone.staging.zone_id
  name    = "argocd"  # argocd.staging.playball.one
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.monitoring.domain_name
    zone_id                = aws_cloudfront_distribution.monitoring.hosted_zone_id
    evaluate_target_health = false
  }
}

# Kiali - CloudFront로 연결
resource "aws_route53_record" "kiali_staging" {
  zone_id = data.aws_route53_zone.staging.zone_id
  name    = "kiali"  # kiali.staging.playball.one
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.monitoring.domain_name
    zone_id                = aws_cloudfront_distribution.monitoring.hosted_zone_id
    evaluate_target_health = false
  }
}

# Swagger - CloudFront로 연결 (OAuth2 Proxy 통해 인증)
resource "aws_route53_record" "swagger_staging" {
  zone_id = data.aws_route53_zone.staging.zone_id
  name    = "swagger"  # swagger.staging.playball.one
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.monitoring.domain_name
    zone_id                = aws_cloudfront_distribution.monitoring.hosted_zone_id
    evaluate_target_health = false
  }
}

# Staging 프론트엔드 (Vercel) - Zone Apex는 CNAME 불가, A + ALIAS 사용
# Note: Vercel의 경우 76.76.21.21 IP 또는 ALIAS 사용
resource "aws_route53_record" "frontend_staging" {
  zone_id = data.aws_route53_zone.staging.zone_id
  name    = ""  # staging.playball.one (Zone Apex)
  type    = "A"
  ttl     = 300
  records = ["76.76.21.21"]  # Vercel's A record for apex domains
}

# www 서브도메인 (Vercel) - CNAME 가능
resource "aws_route53_record" "frontend_www_staging" {
  zone_id = data.aws_route53_zone.staging.zone_id
  name    = "www"  # www.staging.playball.one
  type    = "CNAME"
  ttl     = 300
  records = ["cname.vercel-dns.com"]
}

#############################################
# Note: bastion 레코드는 compute 레이어로 이동
# (aws_eip.bastion은 compute에서 생성되므로)
#############################################
