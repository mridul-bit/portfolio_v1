terraform {
  # Production setup requires remote backend for shared state management
  backend "s3" {
    bucket = "portfolio-v1-tfstate-bucket" # MUST be unique; create this manually first
    key    = "v1/portfolio/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Provider configuration (uses configured AWS CLI credentials)
provider "aws" {
  region = var.aws_region
}

# --- EKS Cluster Definition (Simplified - requires IAM roles) ---
resource "aws_eks_cluster" "portfolio_eks" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_master.arn # Role defined in security.tf (for EKS control plane)
  version  = "1.28" # Stable version
  
  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    endpoint_private_access = true # Best practice
    endpoint_public_access  = false # Best practice: access via bastion or management VPN
  }

  # Ensure the cluster is destroyed gracefully
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# --- Elastic Container Registry (ECR) for Docker Images ---
resource "aws_ecr_repository" "django_repo" {
  name                 = "portfolio-v1-backend-monolith"
  image_tag_mutability = "MUTABLE" # Use Immutable tags in a real enterprise setup (e.g., using digest)

  image_scanning_configuration {
    scan_on_push = true # Mandatory security practice
  }
}

# --- Data Sources (Used to retrieve existing AZs) ---
data "aws_availability_zones" "available" {
  state = "available"
}