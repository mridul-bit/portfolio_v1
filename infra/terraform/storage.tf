  # infra/terraform/storage.tf

  # ---------------------------Frontend S3 Bucket -----------------------------
  resource "aws_s3_bucket" "frontend_bucket" {
    bucket = "${var.project_name}-frontend-static-${var.aws_account_id}"

  }
  resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_encryption" {
    bucket = aws_s3_bucket.frontend_bucket.id
    rule {
    apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  resource "aws_s3_bucket_versioning" "frontend_versioning" {
    bucket = aws_s3_bucket.frontend_bucket.id

    versioning_configuration {
      status = "Enabled"
    }
  }
  resource "aws_s3_bucket_ownership_controls" "frontend_bucket_controls" {
  
    bucket = aws_s3_bucket.frontend_bucket.id 
  
    rule {
      # Valid values: BucketOwnerPreferred, ObjectWriter, BucketOwnerEnforced
      object_ownership = "BucketOwnerEnforced" 
    }
  }

  resource "aws_s3_bucket_public_access_block" "frontend_bucket_pab" {
    bucket = aws_s3_bucket.frontend_bucket.id

  # These settings ensure no one can make the bucket truly public, 
  # but allow the explicit OAC policy to function.
    block_public_acls       = true
    block_public_policy     = false  # false to allow the Bucket Policy
    ignore_public_acls      = true
    restrict_public_buckets = true
  }    


  # ------------------------- Resume S3 Bucket-----------------------
  resource "aws_s3_bucket" "resume_bucket" {
    bucket = "${var.project_name}-resume-data-${var.aws_account_id}"
    
    

    tags = {
      Name = "${var.project_name}-resume-data"
    }
  }

  # -------------------CloudFront Log S3 Bucket ------------------------------------
  resource "aws_s3_bucket" "cf_log_bucket" {
    bucket = "${var.project_name}-cf-access-logs-${var.aws_account_id}"

  }
  resource "aws_s3_bucket_ownership_controls" "cf_log_ownership" {
    bucket = aws_s3_bucket.cf_log_bucket.id
  
    rule {
    
      object_ownership = "ObjectWriter" 
    }
  }
  # ----------------------------Output-------------------------------
  output "frontend_bucket_id" {
    description = "ID of the S3 bucket hosting the frontend."
    value       = aws_s3_bucket.frontend_bucket.id
  }
  output "cf_log_bucket_id" {
    description = "ID of the S3 bucket for CloudFront logs."
    value       = aws_s3_bucket.cf_log_bucket.id
  }