#############################################
# CloudFront - Assets CDN (공통)
# assets.playball.one → S3 goormgb-assets
#############################################

data "aws_caller_identity" "current" {}

# S3 Origin Access Control
resource "aws_cloudfront_origin_access_control" "assets" {
  count = var.enable_acm ? 1 : 0

  name                              = "assets-oac"
  description                       = "OAC for goormgb-assets S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 Bucket Policy - CloudFront 접근 허용 (static 경로만)
resource "aws_s3_bucket_policy" "assets" {
  count  = var.enable_acm ? 1 : 0
  bucket = "goormgb-assets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontStaticAssets"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = [
          "arn:aws:s3:::goormgb-assets/static/*"
        ]
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.assets[0].arn
          }
        }
      }
    ]
  })
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "assets" {
  count = var.enable_acm ? 1 : 0

  enabled             = true
  comment             = "Assets CDN - playball.one (shared)"
  aliases             = ["assets.${var.domain_name}"]
  price_class         = "PriceClass_200"
  default_root_object = "index.html"

  origin {
    domain_name              = "goormgb-assets.s3.ap-northeast-2.amazonaws.com"
    origin_id                = "s3-assets"
    origin_access_control_id = aws_cloudfront_origin_access_control.assets[0].id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-assets"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # 캐싱 최적화 (정적 파일)
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # CachingOptimized
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.wildcard_cloudfront[0].arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name        = "assets-cloudfront"
    Environment = "shared"
  }

  depends_on = [aws_acm_certificate_validation.wildcard_cloudfront]
}

#############################################
# Route53 Record - assets.playball.one
#############################################

resource "aws_route53_record" "assets" {
  count = var.enable_acm ? 1 : 0

  zone_id = aws_route53_zone.root.zone_id
  name    = "assets"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.assets[0].domain_name
    zone_id                = aws_cloudfront_distribution.assets[0].hosted_zone_id
    evaluate_target_health = false
  }
}
