#############################################
# Outputs
#############################################

# Route53 Hosted Zone
output "root_zone_id" {
  description = "Route53 Hosted Zone ID for playball.one"
  value       = aws_route53_zone.root.zone_id
}

output "root_zone_name_servers" {
  description = "Name servers for playball.one (Porkbun에 설정 필요)"
  value       = aws_route53_zone.root.name_servers
}

# ACM Certificates - CloudFront (us-east-1)
output "wildcard_cert_cloudfront_arn" {
  description = "Wildcard ACM Certificate ARN for CloudFront (us-east-1)"
  value       = var.enable_acm ? aws_acm_certificate.wildcard_cloudfront[0].arn : null
}

# ACM Certificates - Seoul (ap-northeast-2)
output "wildcard_cert_seoul_arn" {
  description = "Wildcard ACM Certificate ARN for ALB/NLB (ap-northeast-2)"
  value       = var.enable_acm ? aws_acm_certificate.wildcard_seoul[0].arn : null
}

# Assets CDN
output "assets_cdn_domain" {
  description = "Assets CloudFront distribution domain"
  value       = var.enable_acm ? aws_cloudfront_distribution.assets[0].domain_name : null
}

output "assets_cdn_url" {
  description = "Assets CDN URL"
  value       = var.enable_acm ? "https://assets.${var.domain_name}" : null
}

#############################################
# Porkbun DNS 설정 안내
#############################################
output "porkbun_ns_records" {
  description = "Porkbun에 추가할 NS 레코드"
  value = <<-EOT

    ========================================
    Porkbun DNS 설정 방법
    ========================================

    1. Porkbun 로그인 → Domain Management → playball.one
    2. DNS Records 탭
    3. 기존 NS 레코드 삭제 (있다면)
    4. 아래 NS 레코드 추가:

    ${join("\n    ", [for ns in aws_route53_zone.root.name_servers : "Type: NS, Host: (blank), Answer: ${ns}"])}

    ========================================
  EOT
}
