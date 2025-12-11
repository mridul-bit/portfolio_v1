# infra/terraform/waf.tf



# --- 1. AWS WAFv2 Web ACL (Global for CloudFront) ---
resource "aws_wafv2_web_acl" "portfolio_waf" {
  name        = "${var.project_name}-web-acl"
  description = "WAFv2 for Portfolio CloudFront Distribution with managed rules and rate limiting."
  scope       = "CLOUDFRONT" # CRITICAL: Scope must be CLOUDFRONT
  provider = aws.us-east-1
  
  default_action {
    allow {}
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "PortfolioWAF"
    sampled_requests_enabled   = true
  }

  # --- Rule 1: AWS Managed Rules (Common Attack Protection) ---
  rule {
    name      = "AWS-Managed-Common-Rules"
    priority  = 1

    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
  
  # --- Rule 2 (Rate Limiting Rule - IP-based Throttling) ---
  rule {
    name      = "IPRateLimit"
    priority  = 3 
    
    action {
      block {} # Block requests that exceed the limit
    }
    
    # CRITICAL FIX: The rate_limit_statement MUST be directly inside the statement block.
    statement {
      rate_based_statement {
        limit               = 200
        aggregate_key_type  = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CloudFrontRateLimitMetric"
      sampled_requests_enabled   = true
    }
  }
}