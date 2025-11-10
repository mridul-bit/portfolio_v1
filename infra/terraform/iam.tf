# 1. EKS Control Plane IAM Role
resource "aws_iam_role" "eks_master" {
  name = "${var.eks_cluster_name}-master-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_master.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# 2. IAM Role for EKS Worker Nodes (Used by the EKS Node Group)
resource "aws_iam_role" "eks_node" {
  name = "${var.eks_cluster_name}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_policy_1" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
# ... Attach CNI and Registry policies ...

# 3. IAM Role for Django Pods (IRSA)
resource "aws_iam_role" "django_app_irsa_role" {
  name = "portfolio-django-role"

  # Trust policy for the EKS Service Account
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/${replace(aws_eks_cluster.portfolio_eks.identity[0].oidc[0].issuer, "https://", "")}"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # Binds this role only to the specified K8s Service Account and namespace
            "${replace(aws_eks_cluster.portfolio_eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:default:django-sa"
          }
        }
      }
    ]
  })
}

# 4. IAM Policy for Django Pods (Least Privilege)
resource "aws_iam_policy" "django_app_policy" {
  name        = "portfolio-django-access-policy"
  description = "Access policy for Django to S3, Secrets Manager, and Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowSecretsAccess",
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
        ],
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn,
          # ... other secrets
        ]
      },
      {
        Sid    = "AllowS3PresignAccess",
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        # Restrict access only to the resume file in the secure bucket
        Resource = "arn:aws:s3:::${aws_s3_bucket.resume_bucket.id}/${aws_ssm_parameter.resume_s3_key.value}"
      },
      {
        Sid    = "AllowParameterStoreAccess",
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters", 
          "ssm:GetParametersByPath"
        ],
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter${aws_ssm_parameter.resume_s3_key.name}"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "django_app_attach" {
  role       = aws_iam_role.django_app_irsa_role.name
  policy_arn = aws_iam_policy.django_app_policy.arn
}