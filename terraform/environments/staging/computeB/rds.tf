#############################################
# RDS Subnet Group
#############################################

resource "aws_db_subnet_group" "main" {
  name        = local.rds_db_subnet_group_name
  description = "Database subnet group for ${var.owner_name}"
  subnet_ids  = local.private_subnet_ids

  tags = {
    Name = "${var.owner_name}-${var.environment}-db-subnet-group"
  }
}

#############################################
# RDS Security Group
#############################################

resource "aws_security_group" "rds" {
  name        = "${var.owner_name}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = local.vpc_id

  # EKS 노드에서 PostgreSQL 접근
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.cluster_security_group_id]
    description     = "PostgreSQL from EKS"
  }

  # Bastion에서 PostgreSQL 접근 (관리용)
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "PostgreSQL from Bastion"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.owner_name}-${var.environment}-rds-sg"
  }
}

#############################################
# RDS PostgreSQL Instance
#############################################

resource "aws_db_instance" "main" {
  identifier = local.rds_identifier

  engine                = "postgres"
  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Staging: 단일 AZ (비용 절약)
  multi_az            = false
  publicly_accessible = false

  # 백업 설정
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # 파라미터 그룹
  parameter_group_name = aws_db_parameter_group.main.name

  # 삭제 보호 (staging에서는 비활성화)
  deletion_protection       = false
  skip_final_snapshot       = true
  final_snapshot_identifier = null

  # 성능 인사이트 (무료 tier)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = {
    Name = "${var.owner_name}-${var.environment}-postgresql"
  }
}

#############################################
# RDS Parameter Group
#############################################

resource "aws_db_parameter_group" "main" {
  name        = local.rds_parameter_group_name
  family      = "postgres16"
  description = "PostgreSQL parameter group for ${var.owner_name}"

  parameter {
    name  = "timezone"
    value = "Asia/Seoul"
  }

  parameter {
    name  = "log_statement"
    value = "ddl" # 'all'은 성능 저하 유발, 'ddl' 또는 'mod' 권장
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = {
    Name = "${var.owner_name}-${var.environment}-postgresql-params"
  }
}
