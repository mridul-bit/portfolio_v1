# --- Global AWS Config ---
variable "aws_region" {
  description = "The AWS region to deploy resources to."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "The AWS Account ID"
  type        = string
  # IMPORTANT: Replace with your actual AWS Account ID
  default     = "123456789012" 
}

# --- Domain & Networking ---
variable "domain_name" {
  description = "The root domain name for the portfolio."
  type        = string
  default     = "yourportfolio.com" 
}

# --- EKS Config ---
variable "eks_cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
  default     = "portfolio-v1-eks"
}

# --- Sensitive/Secret Variables (Input via CLI or TF Cloud) ---
variable "db_password_secret" {
  description = "The initial password for the RDS database (will be stored in Secrets Manager)."
  type        = string
  sensitive   = true # Mark as sensitive
}