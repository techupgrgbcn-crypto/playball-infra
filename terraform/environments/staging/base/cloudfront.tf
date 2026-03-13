#############################################
# CloudFront - API
#############################################

resource "aws_cloudfront_distribution" "api" {
  enabled             = true
  comment             = "API - staging.playball.one"
  aliases             = ["api.staging.${var.domain_name}"]
  price_class         = "PriceClass_200"  # Asia, Europe, North America
  default_root_object = ""

  origin {
    domain_name = var.api_nlb_domain  # NLB DNS (computeA or computeB)
    origin_id   = "api-nlb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "api-nlb"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # API는 캐싱 안 함
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"  # CachingDisabled
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"  # AllViewer

    # SSE 지원을 위한 설정
    response_headers_policy_id = null
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.staging_cloudfront.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # WAF 없음! (Pay as you go이므로 선택적)
  web_acl_id = null

  tags = {
    Name = "api-staging-cloudfront"
    Type = "api"
  }
}

#############################################
# CloudFront - Monitoring
# grafana, argocd, kiali 통합
#############################################

resource "aws_cloudfront_distribution" "monitoring" {
  enabled             = true
  comment             = "Monitoring tools - staging.playball.one"
  aliases             = [
    "grafana.staging.${var.domain_name}",
    "argocd.staging.${var.domain_name}",
    "kiali.staging.${var.domain_name}",
    "swagger.staging.${var.domain_name}"
  ]
  price_class         = "PriceClass_200"
  default_root_object = ""

  origin {
    domain_name = var.monitoring_nlb_domain  # NLB DNS (computeA or computeB)
    origin_id   = "monitoring-nlb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "monitoring-nlb"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # 모니터링 도구는 캐싱 안 함
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"  # CachingDisabled
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"  # AllViewer
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.staging_cloudfront.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # 무료 플랜이면 AWS 콘솔에서 설정 (Terraform에서는 제어 불가)
  # 여기서는 WAF 없이 생성, 콘솔에서 무료 플랜으로 전환

  tags = {
    Name = "monitoring-staging-cloudfront"
    Type = "monitoring"
  }
}

