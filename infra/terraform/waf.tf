# 1. WAF Rate Limiting Rule (CTO-level Throttling)
resource "aws_wafv2_web_acl" "rate_limit_acl" {
  name        = "PortfolioV1RateLimitACL"
  scope       = "REGIONAL" # Apply to ALB (not CloudFront)
  description = "Rate limiting for the EKS Monolith API"
  default_action {
    allow {} # Default action is to allow
  }
  
  # Rule: Block requests exceeding 100/5 minutes from the same IP
  rule {
    name     = "IPRateLimit"
    priority = 1
    action {
      block {}
    }
    statement {
      rate_limit_statement {
        limit               = 100 # Block after 100 requests (generous limit for testing)
        aggregate_key_type  = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "PortfolioRateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name = "PortfolioV1WAF"
  }
}