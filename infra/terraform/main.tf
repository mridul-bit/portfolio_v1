# infra/terraform/main.tf

terraform { #defining plugin used in terraform
  backend "s3" {
    bucket  = "portfolio-v1-tfstate-bucket" #created beforehand manually
    key     = "v1/portfolio/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    # Added random provider dependency since using random_password/random_string
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0" 
    }
  }
}
 
provider "aws" {
  region = var.aws_region
}


