#############################################
# ElastiCache Subnet Group
#############################################

resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.environment}-redis-subnet-group"
  description = "Redis subnet group for ${var.environment}"
  subnet_ids  = local.private_subnet_ids

  tags = {
    Name = "${var.environment}-redis-subnet-group"
  }
}

#############################################
# ElastiCache Security Group
#############################################

resource "aws_security_group" "redis" {
  name        = "${var.environment}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = local.vpc_id

  # EKS 노드에서 Redis 접근
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.eks.cluster_security_group_id]
    description     = "Redis from EKS"
  }

  # Bastion에서 Redis 접근 (관리용)
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "Redis from Bastion"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-redis-sg"
  }
}

#############################################
# ElastiCache Parameter Group
#############################################

resource "aws_elasticache_parameter_group" "cache" {
  name        = "${var.environment}-redis-cache-params"
  family      = "redis7"
  description = "Redis parameter group for cache"

  # 캐시용: 메모리 부족시 오래된 키 삭제
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = {
    Name = "${var.environment}-redis-cache-params"
  }
}

resource "aws_elasticache_parameter_group" "queue" {
  name        = "${var.environment}-redis-queue-params"
  family      = "redis7"
  description = "Redis parameter group for queue"

  # 큐용: 데이터 유실 방지 (메모리 부족시 에러)
  parameter {
    name  = "maxmemory-policy"
    value = "noeviction"
  }

  tags = {
    Name = "${var.environment}-redis-queue-params"
  }
}

#############################################
# ElastiCache Redis - Cache (세션, API 캐시)
#############################################

resource "aws_elasticache_cluster" "cache" {
  cluster_id           = "${var.environment}-redis-cache"
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_cache_node_type
  num_cache_nodes      = 1
  port                 = 6379

  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]
  parameter_group_name = aws_elasticache_parameter_group.cache.name

  # 스냅샷 (캐시는 선택적)
  snapshot_retention_limit = 0

  # 유지보수 윈도우
  maintenance_window = "Mon:05:00-Mon:06:00"

  tags = {
    Name = "${var.environment}-redis-cache"
    Type = "cache"
  }
}

#############################################
# ElastiCache Redis - Queue (대기열, 좌석 선점)
#############################################

resource "aws_elasticache_cluster" "queue" {
  cluster_id           = "${var.environment}-redis-queue"
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_queue_node_type
  num_cache_nodes      = 1
  port                 = 6379

  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]
  parameter_group_name = aws_elasticache_parameter_group.queue.name

  # 큐는 스냅샷 유지 (데이터 유실 방지)
  snapshot_retention_limit = 1
  snapshot_window         = "02:00-03:00"

  # 유지보수 윈도우
  maintenance_window = "Mon:05:00-Mon:06:00"

  tags = {
    Name = "${var.environment}-redis-queue"
    Type = "queue"
  }
}
