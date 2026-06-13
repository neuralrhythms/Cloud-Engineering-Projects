################################################################################
# Compute — ECS Fargate Cluster, ALB, ECR, MGN Launch Template, Security Groups
# Reference framework for VMware → AWS Cloud Native Migration
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      TerraformManaged = "true"
      Environment      = var.environment
      Owner            = var.owner_tag
      CostCentre       = var.cost_centre
    }
  }
}

################################################################################
# Security Groups — ALB
################################################################################

resource "aws_security_group" "alb" {
  name        = "sg-${var.environment}-alb"
  description = "Application Load Balancer security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP redirect from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-${var.environment}-alb" }
}

################################################################################
# Security Groups — ECS Web Tasks
################################################################################

resource "aws_security_group" "ecs_web" {
  name        = "sg-${var.environment}-app-web"
  description = "ECS web tier tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-${var.environment}-app-web" }
}

################################################################################
# Security Groups — ECS/EC2 Backend
################################################################################

resource "aws_security_group" "app_backend" {
  name        = "sg-${var.environment}-app-backend"
  description = "EC2 rehosted workloads and ECS backend tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App traffic from web tier"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-${var.environment}-app-backend" }
}

################################################################################
# Security Groups — MGN Replication Servers
################################################################################

resource "aws_security_group" "mgn" {
  name        = "sg-${var.environment}-mgn"
  description = "MGN replication server — accepts agent replication traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "MGN agent replication from SDDC"
    from_port   = 1500
    to_port     = 1500
    protocol    = "tcp"
    cidr_blocks = var.sddc_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-${var.environment}-mgn" }
}

################################################################################
# Application Load Balancer
################################################################################

resource "aws_lb" "main" {
  name               = "alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = true
  drop_invalid_header_fields = true

  access_logs {
    bucket  = var.alb_access_logs_bucket
    prefix  = "alb/${var.environment}"
    enabled = true
  }

  tags = { Name = "alb-${var.environment}" }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_app.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_target_group" "web_app" {
  name        = "tg-web-app-${var.environment}"
  port        = 443
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    protocol            = "HTTPS"
  }

  tags = { Name = "tg-web-app-${var.environment}" }
}

################################################################################
# WAF — Web ACL
################################################################################

resource "aws_wafv2_web_acl" "main" {
  name  = "waf-${var.environment}"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsMetric"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-${var.environment}"
    sampled_requests_enabled   = true
  }

  tags = { Name = "waf-${var.environment}" }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

################################################################################
# ECR Repositories
################################################################################

resource "aws_ecr_repository" "web_app" {
  name                 = "web-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_ebs_arn
  }

  tags = { Name = "ecr-web-app" }
}

resource "aws_ecr_repository" "app_backend" {
  name                 = "app-backend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_ebs_arn
  }

  tags = { Name = "ecr-app-backend" }
}

resource "aws_ecr_lifecycle_policy" "web_app" {
  repository = aws_ecr_repository.web_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v"]
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus = "untagged"
          countType = "sinceImagePushed"
          countUnit = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}

################################################################################
# ECS Cluster
################################################################################

resource "aws_ecs_cluster" "main" {
  name = "ecs-${var.environment}-workloads"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "ecs-${var.environment}-workloads" }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

################################################################################
# CloudWatch Log Groups — ECS
################################################################################

resource "aws_cloudwatch_log_group" "ecs_web" {
  name              = "/ecs/${var.environment}/web-app"
  retention_in_days = 30

  tags = { Name = "lg-ecs-web-app-${var.environment}" }
}

resource "aws_cloudwatch_log_group" "ecs_backend" {
  name              = "/ecs/${var.environment}/app-backend"
  retention_in_days = 30

  tags = { Name = "lg-ecs-backend-${var.environment}" }
}

################################################################################
# ECS Task Definition — Web Application
################################################################################

resource "aws_ecs_task_definition" "web_app" {
  family                   = "td-web-app-${var.environment}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "web-app"
      image     = "${aws_ecr_repository.web_app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 443
          hostPort      = 443
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "ENV", value = var.environment },
        { name = "AWS_REGION", value = var.aws_region }
      ]

      secrets = [
        {
          name      = "DB_CONNECTION_STRING"
          valueFrom = var.db_secret_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_web.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "web-app"
        }
      }

      readonlyRootFilesystem = true

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f https://localhost/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name          = "td-web-app-${var.environment}"
    Application   = "web-app"
    MigrationWave = "wave-3"
  }
}

################################################################################
# ECS Service — Web Application
################################################################################

resource "aws_ecs_service" "web_app" {
  name            = "svc-web-app-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web_app.arn
  desired_count   = var.ecs_web_desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100
    base              = 1
  }

  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [aws_security_group.ecs_web.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web_app.arn
    container_name   = "web-app"
    container_port   = 443
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  enable_execute_command = false

  lifecycle {
    ignore_changes = [desired_count] # Managed by auto-scaling
  }

  tags = {
    Name        = "svc-web-app-${var.environment}"
    Application = "web-app"
  }
}

################################################################################
# ECS Auto-Scaling
################################################################################

resource "aws_appautoscaling_target" "ecs_web" {
  max_capacity       = var.ecs_web_max_count
  min_capacity       = var.ecs_web_desired_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.web_app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_web_cpu" {
  name               = "asg-ecs-web-cpu-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_web.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_web.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_web.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

################################################################################
# MGN Launch Template (for rehosted EC2 workloads post-migration)
################################################################################

resource "aws_launch_template" "mgn_rehost" {
  name_prefix   = "lt-mgn-rehost-${var.environment}-"
  description   = "Launch template for MGN-migrated EC2 instances"
  image_id      = "ami-PLACEHOLDER" # MGN overwrites this; placeholder required by Terraform

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 enforced
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  iam_instance_profile {
    name = var.ec2_instance_profile_name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      encrypted             = true
      kms_key_id            = var.kms_key_ebs_arn
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  vpc_security_group_ids = [aws_security_group.app_backend.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Install CloudWatch Agent
    yum install -y amazon-cloudwatch-agent 2>/dev/null || \
    apt-get install -y amazon-cloudwatch-agent 2>/dev/null
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -s \
      -c ssm:/cloudwatch-agent/config/default
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name          = "ec2-rehost-${var.environment}"
      MigrationWave = "wave-2"
      PatchGroup    = "linux-${var.environment}"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name       = "ebs-rehost-${var.environment}"
      Encrypted  = "true"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
