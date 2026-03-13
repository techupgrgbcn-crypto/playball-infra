#############################################
# Route53 Hosted Zone - staging.playball.one
#############################################

resource "aws_route53_zone" "this" {
  name = "${var.environment}.${var.domain_name}"

  tags = {
    Name        = "${var.environment}.${var.domain_name}"
    Environment = var.environment
  }
}
