# infra/terraform/ecs.tf


# --- --------------- ECS Cluster ------------------
resource "aws_ecs_cluster" "portfolio_ecs" {
  name = "${var.project_name}-cluster"
  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# --- -----------CloudWatch Log Group for ECS --------------

resource "aws_cloudwatch_log_group" "django_log_group" {
  name              = "/ecs/${var.project_name}-django"
  retention_in_days = 30
}

# ----------------------ECR Repository for Docker Image -------

resource "aws_ecr_repository" "django_repo" {
  name                 = "${var.project_name}-django-repo"
  image_tag_mutability = "MUTABLE" # Allows overwriting 'latest'

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ---------------------- ECS Task Definition ----------------------
resource "aws_ecs_task_definition" "django_monolith_task" {
  family                   = "${var.project_name}-django-monolith-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512    
  memory                   = 1024   

  execution_role_arn       = aws_iam_role.ecs_execution_role.arn 
  task_role_arn            = aws_iam_role.django_app_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "django-monolith"
     
      image     = aws_ecr_repository.django_repo.repository_url
      cpu       = 512
      memory    = 1024
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
        }
      ]
      environment = [
        # Pass non-sensitive configuration
        { name = "DB_HOST", value = aws_db_instance.postgres_db.address }, 
        { name = "DB_PORT", value = "5432" }, 
        { name = "ALLOWED_HOSTS", value = "*.${var.domain_name}" },
        { name = "RESUME_BUCKET_NAME", value = aws_s3_bucket.resume_bucket.id },
        { name = "RESUME_S3_KEY", value = aws_ssm_parameter.resume_s3_key.value },
      ]
      secrets = [
        # Pass sensitive secrets from AWS Secrets Manager
        { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:DB_PASSWORD::" },
        { name = "DB_USERNAME", valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:DB_USERNAME::" },
        { name = "DJANGO_SECRET_KEY", valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:DJANGO_SECRET_KEY::" },
        { name = "DB_NAME", valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:DB_NAME::" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.django_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  
  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution_role_policy, 
    aws_iam_role_policy_attachment.django_app_attach,
    aws_db_instance.postgres_db,        
    aws_secretsmanager_secret.db_credentials, 
    aws_s3_bucket.resume_bucket,        
    aws_ssm_parameter.resume_s3_key,
  ]
}

# --- ---------------------- ECS Service (Controls running tasks)------------------------ ---

resource "aws_ecs_service" "django_service" {
  name            = "${var.project_name}-django-service"
  cluster         = aws_ecs_cluster.portfolio_ecs.id
  task_definition = aws_ecs_task_definition.django_monolith_task.arn
  # desired_count  managed by auto-scaling 
  desired_count   = 1 
  launch_type     = "FARGATE"
  #USED DURING ROLLING DEPLOYMENT
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.fargate_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.fargate.arn 
    container_name   = "django-monolith"
    container_port   = 8000
  }

  depends_on = [
    aws_lb_listener.https_listener,
    aws_lb_listener.http_redirect, 
    aws_lb_target_group.fargate,
    aws_iam_role_policy_attachment.ecs_execution_role_policy
  ]
}