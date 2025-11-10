# 1. AWS Certificate Manager (ACM) - Free SSL/TLS
resource "aws_acm_certificate" "portfolio_cert" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

# 2. S3 Bucket for Frontend (Public via CDN)
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "portfolio-v1-frontend-${var.aws_account_id}"
}

# 3. S3 Bucket for Secure Resume (Private)
resource "aws_s3_bucket" "resume_bucket" {
  bucket = "portfolio-v1-resume-${var.aws_account_id}"
}

# 4. CloudFront Origin Access Identity (OAI) for S3 Security
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for accessing S3 frontend bucket securely"
}

# 5. CloudFront Distribution (CDN)
resource "aws_cloudfront_distribution" "portfolio_cdn" {
  # ... standard distribution settings ...
  enabled = true
  
  # Origin 1: Static Frontend (S3)
  origin {
    domain_name = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id   = "S3-Frontend"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  # Origin 2: Django API (EKS ALB) - Must be configured AFTER ALB is provisioned by EKS
  origin {
    domain_name = aws_lb.eks_ingress_alb.dns_name # Placeholder for the ALB provisioned by the K8s Controller
    origin_id   = "EKS-Backend-ALB"
    custom_origin_config {
      http_port  = 80
      https_port = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "S3-Frontend"
    viewer_protocol_policy = "redirect-to-https"
    # ... other caching settings for React static files ...
  }
  
  # API Routing Behavior (CTO-level: bypass cache and forward securely to backend)
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "EKS-Backend-ALB"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "POST"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization"]
      cookies {
        forward = "none"
      }
    }
  }

  # SSL/TLS Termination using ACM
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.portfolio_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021" 
  }
}