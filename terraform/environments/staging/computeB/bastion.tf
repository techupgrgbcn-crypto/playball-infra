#############################################
# Bastion Security Group
#############################################

resource "aws_security_group" "bastion" {
  name        = "${var.owner_name}-${var.environment}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = local.vpc_id

  # SSH from allowed IPs only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidrs
    description = "SSH from allowed IPs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.owner_name}-${var.environment}-bastion-sg"
  }
}

#############################################
# Bastion IAM Role (SSM 접속용)
#############################################

resource "aws_iam_role" "bastion" {
  name = "${var.owner_name}-${var.environment}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.owner_name}-${var.environment}-bastion-role"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.owner_name}-${var.environment}-bastion-profile"
  role = aws_iam_role.bastion.name
}

#############################################
# Bastion EC2 Instance
#############################################

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = local.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  key_name                    = var.bastion_key_name != "" ? var.bastion_key_name : null
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.bastion_root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y postgresql15 redis6
  EOF

  tags = {
    Name = "${var.owner_name}-${var.environment}-bastion"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

#############################################
# Bastion Elastic IP (고정 IP)
#############################################

resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = {
    Name = "${var.owner_name}-${var.environment}-bastion-eip"
  }
}
