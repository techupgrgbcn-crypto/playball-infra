#############################################
# Outputs
#############################################

# Route53 Hosted Zone
output "zone_id" {
  description = "Route53 Hosted Zone ID for staging.playball.one"
  value       = aws_route53_zone.this.zone_id
}

output "zone_name_servers" {
  description = "Name servers for staging.playball.one"
  value       = aws_route53_zone.this.name_servers
}

# ACM Certificates
output "acm_seoul_arn" {
  description = "ACM Certificate ARN (ap-northeast-2)"
  value       = aws_acm_certificate.seoul.arn
}

output "acm_cloudfront_arn" {
  description = "ACM Certificate ARN for CloudFront (us-east-1)"
  value       = aws_acm_certificate.cloudfront.arn
}
