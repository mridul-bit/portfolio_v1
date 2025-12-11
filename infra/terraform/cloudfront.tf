# infra/terraform/cloudfront.tf


# ------------------------- Data Sources for AWS Managed Policies------------------ ---
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewerExceptHostHeader"
}

# ----------------- Origin Access Control (OAC) -------------------
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project_name}_oac"
  description                       = "OAC for S3 Frontend Bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


locals {
  s3_oac_read_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect  = "Allow",
        Principal = {
          # FIX: Use the 'Service' principal, which is required for OAC policies
          Service = "cloudfront.amazonaws.com"
        },
        Action  = "s3:GetObject",
        Resource = [
          # Allows access to all objects (required for GetObject)
          "${aws_s3_bucket.frontend_bucket.arn}/*",
          # IMPORTANT: Include the bucket ARN itself for potential ListBucket checks
          aws_s3_bucket.frontend_bucket.arn 
        ],
        Condition = {
          # This is the security control that restricts access to only YOUR CDN
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.portfolio_cdn.arn 
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = local.s3_oac_read_policy
}




# -----------------CloudFront --------------------------------- ---
resource "aws_cloudfront_distribution" "portfolio_cdn" {
  origin {
    domain_name              = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id                = "s3-frontend-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for Portfolio Frontend"
  price_class         = "PriceClass_200"
  default_root_object = "index.html"

  web_acl_id          = aws_wafv2_web_acl.portfolio_waf.arn

  aliases = [var.domain_name, "www.${var.domain_name}"]

  default_cache_behavior {
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD", "OPTIONS"]
    target_origin_id         = "s3-frontend-origin"
    viewer_protocol_policy   = "redirect-to-https"
    min_ttl                  = 0
    default_ttl              = 86400
    max_ttl                  = 31536000

    # CORRECTED: Use data block lookup for CachingOptimized policy
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id

    # CORRECTED: Use data block lookup for AllViewer policy
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  # Custom error response for Single Page Application (SPA)
  custom_error_response {
    error_code           = 403
    response_code        = 200
    response_page_path   = "/index.html"
  }
  custom_error_response {
    error_code           = 404
    response_code        = 200
    response_page_path   = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  logging_config {
    bucket          = aws_s3_bucket.cf_log_bucket.bucket_domain_name
    include_cookies = false
    prefix          = "cf-access-logs/"
  }
  depends_on = [
    aws_wafv2_web_acl.portfolio_waf,
    aws_acm_certificate.cert,
    aws_acm_certificate_validation.cert_validation,
    aws_s3_bucket.cf_log_bucket
  ]
}
#---------------------output----------------------------------
output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.portfolio_cdn.id
}
output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = aws_cloudfront_distribution.portfolio_cdn.domain_name
}