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
        
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn,
        ]
      },
      {
        Sid      = "AllowParameterStoreAccess",
        Effect   = "Allow",
        Action   = ["ssm:GetParameter", "ssm:GetParameters"],
      
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
  description = "Permissions for GitHub Actions to deploy to ECS and run migrations."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # 1. ECR Access (Assuming this is for image pull/push)
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart", 
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ],
        Resource = "*"
      },
      # 2. ECS Task/Service Management (Create/Update Service and Register/Describe TD)
      {
        Effect = "Allow",
        Action = [
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeServices",
          "ecs:DescribeClusters",
          "ecs:ListServices",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeListeners",
          "application-autoscaling:Describe*",
          "application-autoscaling:PutScalingPolicy",
          "application-autoscaling:RegisterScalableTarget",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:PutMetricAlarm"
        ],
        Resource = "*"
      },
      # 3. ECS RunTask (THE CRITICAL BLOCK for Migration)
      # Must use Resource: "*" with Condition to satisfy Fargate internal checks.
      {
        Effect = "Allow",
        Action = [
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DescribeTasks"
        ],
        "Resource": [
          // 1. Must include the specific Task Definition family ARN with wildcard revision
          // This directly addresses the error "on resource: arn:aws:ecs:***:task-definition/***:13"
          "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:task-definition/${aws_ecs_task_definition.django_monolith_task.family}:*",
          
          // 2. Must still include the wildcard for Fargate's internal checks
          "*"
        ],
        Condition = {
          "ArnEquals" = {
            "ecs:cluster" = aws_ecs_cluster.portfolio_ecs.arn
          },
          "StringEquals" = {
            "ecs:task-definition" = aws_ecs_task_definition.django_monolith_task.family
          }
        }
      },
      # 4. IAM PassRole (Required to delegate roles to ECS)
      {
        Effect = "Allow",
        Action = [
          "iam:PassRole"
        ],
        Resource = [
          aws_iam_role.django_app_task_role.arn,
          aws_iam_role.ecs_execution_role.arn
        ],
        Condition = {
          "StringEquals" = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
  
        }
      },
      # 5. EC2 Networking Describe (Non-Obvious Fargate Dependency)
      # Required by the calling role to validate the network parameters passed to RunTask.
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs"
        ],
        Resource = "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress"
        ],
        "Resource": [
          // This must be the ARN of the Security Group used by RunTask
          // You must update this with the actual Security Group ARN!
          aws_security_group.fargate_tasks.arn,
          // And the ARN of the Subnets used by RunTask
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:subnet/*"
        ]
      },
      # 6. CloudWatch Logs (To view migration task output)
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/ecs/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cicd_deploy_attach" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.cicd_deploy_policy.arn
}