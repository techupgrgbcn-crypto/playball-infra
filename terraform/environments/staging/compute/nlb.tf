#############################################
# CloudFront Managed Prefix List
#############################################

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

#############################################
# NLB Security Group (타겟용 - CloudFront만 허용)
#############################################

resource "aws_security_group" "nlb_targets" {
  name        = "${var.environment}-nlb-targets-sg"
  description = "Security group for NLB targets (Istio IngressGateway)"
  vpc_id      = local.vpc_id

  # HTTPS from CloudFront only
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
    description     = "HTTPS from CloudFront"
  }

  # HTTP from CloudFront only (for redirect)
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
    description     = "HTTP redirect from CloudFront"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-nlb-targets-sg"
  }
}

# Note: 실제 NLB는 Istio IngressGateway가 생성함 (Kubernetes Service type: LoadBalancer)
# Terraform에서는 NLB를 직접 생성하지 않고, Istio가 생성한 NLB를 data source로 참조할 수 있음
