################################################################################
# Neptune Subnet Group
################################################################################

resource "aws_neptune_subnet_group" "main" {
  name       = "${var.name_prefix}-neptune-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-neptune-subnet-group"
  })
}

################################################################################
# Neptune Parameter Group
################################################################################

resource "aws_neptune_cluster_parameter_group" "main" {
  name   = "${var.name_prefix}-neptune-cluster-params"
  family = "neptune1.3"

  parameter {
    name  = "neptune_enable_audit_log"
    value = "1"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-neptune-cluster-params"
  })
}

################################################################################
# Neptune Security Group
################################################################################

data "aws_security_groups" "lambda" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["*lambda*"]
  }
}

resource "aws_security_group" "neptune" {
  name_prefix = "${var.name_prefix}-neptune-"
  description = "Security group for Neptune cluster"
  vpc_id      = var.vpc_id

  ingress {
    description = "Neptune access from Lambda"
    from_port   = 8182
    to_port     = 8182
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-neptune-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Neptune Cluster
################################################################################

resource "aws_neptune_cluster" "main" {
  cluster_identifier                   = "${var.name_prefix}-neptune-cluster"
  engine                               = "neptune"
  engine_version                       = "1.3.1.0"
  neptune_subnet_group_name            = aws_neptune_subnet_group.main.name
  neptune_cluster_parameter_group_name = aws_neptune_cluster_parameter_group.main.name
  vpc_security_group_ids               = [aws_security_group.neptune.id]
  storage_encrypted                    = true
  kms_key_arn                          = var.kms_key_arn
  backup_retention_period              = 7
  preferred_backup_window              = "03:00-04:00"
  preferred_maintenance_window         = "sun:05:00-sun:06:00"
  skip_final_snapshot                  = false
  final_snapshot_identifier            = "${var.name_prefix}-neptune-final-snapshot"
  iam_database_authentication_enabled  = true
  deletion_protection                  = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-neptune-cluster"
  })
}

################################################################################
# Neptune Cluster Instance (Writer)
################################################################################

resource "aws_neptune_cluster_instance" "writer" {
  identifier                   = "${var.name_prefix}-neptune-writer"
  cluster_identifier           = aws_neptune_cluster.main.id
  instance_class               = var.instance_class
  neptune_subnet_group_name    = aws_neptune_subnet_group.main.name
  publicly_accessible          = false
  auto_minor_version_upgrade   = true
  preferred_maintenance_window = "sun:05:00-sun:06:00"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-neptune-writer"
  })
}
