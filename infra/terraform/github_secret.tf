# infra/terraform/github_secrets.tf


provider "github" {
  owner = var.github_organization 
  token = var.github_token # CRITICAL: This PAT is only needed for the *initial* Terraform run to set the secrets.
}

resource "github_actions_secret" "aws_region_secret" {
  repository      = var.github_repository
  secret_name     = "AWS_REGION"

  plaintext_value = var.aws_region
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
resource "github_actions_secret" "resume_s3_key_value" {
  repository      = var.github_repository
  secret_name     = "RESUME_S3_KEY"
  plaintext_value = aws_ssm_parameter.resume_s3_key.value
}

#--------------------bucket secrets---------------------------- 
resource "github_actions_secret" "s3_frontend_bucket" { 
  repository      = var.github_repository
  secret_name     = "S3_FRONTEND_BUCKET"
  
  plaintext_value = aws_s3_bucket.frontend_bucket.id
}


resource "github_actions_secret" "resume_bucket_id" {
  repository      = var.github_repository
  secret_name     = "RESUME_BUCKET_ID"
  
  plaintext_value = aws_s3_bucket.resume_bucket.id
}




# --------------------- Backend (ECR/ECS) Secrets -------------------------

resource "github_actions_secret" "ecr_repository" {
  repository      = var.github_repository
  secret_name     = "ECR_REPOSITORY"
 
  plaintext_value = aws_ecr_repository.django_repo.name
}

resource "github_actions_secret" "ecs_cluster_name" {
  repository      = var.github_repository
  secret_name     = "ECS_CLUSTER_NAME"
  
  plaintext_value = aws_ecs_cluster.portfolio_ecs.name
}

resource "github_actions_secret" "ecs_service_name" {
  repository      = var.github_repository
  secret_name     = "ECS_SERVICE_NAME"
  
  plaintext_value = aws_ecs_service.django_service.name
}

resource "github_actions_secret" "ecs_task_definition_family" {
  repository      = var.github_repository
  secret_name     = "ECS_TASK_DEFINITION_FAMILY"
  
  plaintext_value = aws_ecs_task_definition.django_monolith_task.family
}


resource "github_actions_secret" "ecs_container_name" {
  repository      = var.github_repository
  secret_name     = "CONTAINER_NAME"
  plaintext_value = "django-monolith"
}