# infra/terraform/variables.tf

variable "aws_region" {
  description = "The AWS region to deploy resources to."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "The AWS Account ID. Required for IAM policies and ARN construction."
  type        = string
}


variable "project_name" {
  description = "The name of the overall project, used for resource naming and tagging."
  type        = string
  default     = "portfolio-v1"
}


variable "domain_name" {
  description = "The root domain name for the portfolio"
  type        = string
  default     = "talkwithmridul.work"
}

variable "db_username" {
  description = "Master username for the RDS Postgres instance."
  type        = string
  default     = "portfolioadmin"  
}

variable "db_name" {
  description = "name for the RDS Postgres instance."
  type        = string
  default     = "portfoliodb"  
}

#nees to be true first so zone can be created
variable "create_route53_zone" {
  description = "Set to true to create a new Route 53 Hosted Zone, or false to use an existing one."
  type        = bool
  default     = false
}



variable "github_organization" {
  description = "Your GitHub Organization or Username for OIDC trust."
  type        = string
  default     = "mridul-bit"
}

variable "github_repository" {
  description = "The name of the repository containing the source code and workflows."
  type        = string
  default     = "portfolio_v1"
}

variable "github_token" {
  description = "GitHub PAT used only for setting the initial secrets."
  type        = string
  sensitive   = true
}