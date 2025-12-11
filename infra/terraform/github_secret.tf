# infra/terraform/github_secrets.tf


provider "github" {
  owner = var.github_organization 
  token = var.github_token # CRITICAL: This PAT is only needed for the *initial* Terraform run to set the secrets.
}


resource "github_actions_secret" "gh_actions_deploy_role_arn" {
  repository      = var.github_repository
  secret_name     = "GH_ACTIONS_DEPLOY_ROLE_ARN"
 
  plaintext_value = aws_iam_role.github_actions_role.arn
}


resource "github_actions_secret" "cloudfront_distro_id" {
  repository      = var.github_repository
  secret_name     = "CLOUDFRONT_DISTRO_ID"
  
  plaintext_value = aws_cloudfront_distribution.portfolio_cdn.id
}


resource "github_actions_secret" "s3_frontend_bucket" { 
  repository      = var.github_repository
  secret_name     = "S3_FRONTEND_BUCKET"
  
  plaintext_value = aws_s3_bucket.frontend_bucket.id
}

resource "github_actions_secret" "gh_actions_infra_role_arn" { 
  repository      = var.github_repository
  secret_name     = "GH_ACTIONS_INFRA_ROLE_ARN" 
  
  plaintext_value = aws_iam_role.github_actions_infra_role.arn
}