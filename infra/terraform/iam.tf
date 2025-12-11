# infra/terraform/iam.tf


#---------------------ECS Task Execution Role----------------------------
# Pull images, publish logs, use secrets.

resource "aws_iam_role" "ecs_execution_role" {
  name         = "portfolio-fargate-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect  = "Allow",
        Principal = { Service = "ecs-tasks.amazonaws.com" },
        Action  = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# -------------------------ECS Task Role (Application Access to Secrets Manager, S3, SSM)---------------------------------------
resource "aws_iam_role" "django_app_task_role" {
  name         = "portfolio-django-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect  = "Allow",
        Principal = { Service = "ecs-tasks.amazonaws.com" },
        Action  = "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_policy" "django_app_policy" {
  name        = "portfolio-django-access-policy"
  description = "Least privilege access for Fargate container."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "AllowSecretsManagerAccess",
        Effect   = "Allow",
        # Added the DescribeSecret action, often needed for credential rotation/discovery
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn,
        ]
      },
      {
        Sid      = "AllowParameterStoreAccess",
        Effect   = "Allow",
        Action   = ["ssm:GetParameter", "ssm:GetParameters"],
        # CRITICAL FIX: Use var.project_name to scope access to all /portfolio/* parameters.
        Resource = aws_ssm_parameter.resume_s3_key.arn
      },
      {
        Sid      = "AllowS3ObjectAccess",
        Effect   = "Allow",
        # Allow only GetObject for viewing a resume, etc.
        Action   = ["s3:GetObject"], 
        # Correctly reference the S3 bucket ARN
        Resource = [
          # Allows GetObject on all files in the bucket
          "${aws_s3_bucket.resume_bucket.arn}/*",
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "django_app_attach" {
  role       = aws_iam_role.django_app_task_role.name
  policy_arn = aws_iam_policy.django_app_policy.arn
}


# --- ---------GitHub OIDC Provider Setup ----------------
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  
}

# ----------------------------- GitHub Actions Deployment Role ----------------
resource "aws_iam_role" "github_actions_role" {
  name = "portfolio-github-actions-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringLike = {
            # Only allow sessions from the specific repository
            "token.actions.githubusercontent.com:sub" : "repo:${var.github_organization}/${var.github_repository}:*" 
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "cicd_deploy_policy" {
  name        = "portfolio-cicd-deploy-policy"
  description = "Policy for GitHub Actions to deploy to S3, ECR, and update ECS."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # ECR: Push the new Docker image
      {
        Effect   = "Allow",
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ],
        Resource = aws_ecr_repository.django_repo.arn
      },
      # ECS: Update the service with the new task definition
      {
        Effect   = "Allow",
        Action   = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:RunTask",      # For running the migration task
          "ecs:StopTask",     # To clean up or stop a hanging task
          "ecs:DescribeTasks"
        ],
        Resource = [
          aws_ecs_cluster.portfolio_ecs.arn,
          aws_ecs_service.django_service.id
        ]
      },
      # S3: Sync frontend assets
      {
        Effect   = "Allow",
        Action   = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.frontend_bucket.arn,
          "${aws_s3_bucket.frontend_bucket.arn}/*",
          aws_s3_bucket.resume_bucket.arn,
          "${aws_s3_bucket.resume_bucket.arn}/*"
        ]
      },
      
      # CloudFront: Invalidate the cache after frontend deployment
      {
        Effect   = "Allow",
        Action   = [
          "cloudfront:CreateInvalidation"
        ],
        Resource = aws_cloudfront_distribution.portfolio_cdn.arn
      },
      {
        Effect: "Allow",
        Action: [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource: aws_cloudwatch_log_group.django_log_group.arn
      },
      {
        Effect = "Allow",
        Action = [
            "iam:PassRole"
        ],
        Resource = [
            aws_iam_role.django_app_task_role.arn,     // Task Role (Application)
            aws_iam_role.ecs_execution_role.arn        // Execution Role (Fargate)
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cicd_deploy_attach" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.cicd_deploy_policy.arn
}