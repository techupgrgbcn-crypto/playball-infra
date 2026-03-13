#############################################
# Data Sources - staging/base 참조 (Route53, ACM)
#############################################

# Base 환경의 Terraform State 참조
data "terraform_remote_state" "base" {
  backend = "s3"

  config = {
    bucket = "goormgb-tf-state"
    key    = "staging/base/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

#############################################
# Local values
#############################################

locals {
  # VPC (compute에서 직접 관리)
  vpc_id             = aws_vpc.main.id
  vpc_cidr           = aws_vpc.main.cidr_block
  public_subnet_ids  = aws_subnet.public[*].id
  private_subnet_ids = aws_subnet.private[*].id

  # Route53 & ACM (base에서 참조)
  staging_zone_id = data.terraform_remote_state.base.outputs.staging_zone_id
  staging_acm_arn = data.terraform_remote_state.base.outputs.staging_acm_arn
}

#############################################
# AMI for Bastion
#############################################

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
