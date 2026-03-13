#############################################
# VPC Endpoints - 네트워크 비용 최적화
#############################################
# 단기 프로젝트에서는 S3 Gateway Endpoint만 사용
# Interface Endpoint는 AZ당 $0.01/hr 비용 발생
# → 트래픽이 적으면 NAT Gateway가 더 저렴
#############################################

#############################################
# S3 Gateway Endpoint (무료!)
#############################################
# Terraform State, 로그, 백업 등 모든 S3 트래픽 최적화
# NAT Gateway 데이터 처리 비용 절감
# Gateway Endpoint는 비용이 발생하지 않음

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.private.id]

  tags = {
    Name        = "${var.environment}-s3-endpoint"
    Environment = var.environment
    Terraform   = "true"
  }
}

#############################################
# 참고: Interface Endpoints (필요 시 활성화)
#############################################
# 대용량 트래픽 (월 2,500GB+) 시 아래 활성화 검토
# 비용: $0.01/hr × AZ 수 × Endpoint 수
#
# - ECR (ecr.api, ecr.dkr): 이미지 Pull 최적화
# - Secrets Manager: External Secrets
# - STS: IRSA 토큰
# - CloudWatch Logs: 로그 전송
# - EC2, ELB, Auto Scaling: EKS 관련
#############################################

#############################################
# Outputs
#############################################

output "vpc_endpoint_s3_id" {
  description = "S3 VPC Endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}
