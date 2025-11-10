# Get the Zone ID for your existing domain (or create one)
data "aws_route53_zone" "primary" {
  name         = "${var.domain_name}." # e.g., "mydomain.com."
  private_zone = false
}

# 1. Frontend Domain Routing (A Record pointing to CloudFront)
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.portfolio_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.portfolio_cdn.hosted_zone_id
    evaluate_target_health = true
  }
}

# 2. API Domain Routing (A Record pointing to EKS Ingress ALB)
# The ALB provisioned by the K8s Ingress controller needs to be targeted.
# This requires querying the K8s Ingress status after deployment.
resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "api.${var.domain_name}" # e.g., api.mydomain.com
  type    = "A"
  
  # NOTE: This assumes we can query the ALB's DNS name from the Ingress resource
  alias {
    # Get the DNS name/Hosted Zone ID from the provisioned ALB
    name                   = aws_lb.eks_ingress_alb.dns_name 
    zone_id                = aws_lb.eks_ingress_alb.hosted_zone_id
    evaluate_target_health = true
  }
}