# infra/terraform/route53.tf

#ROUTE 53 HOSTED ZONE CREATED AND GENERAETS NAMESERVERS(which go daggy will route request to)
# ReQUESTS CETIFCATE aws_acm_certificate cert
# cert_validation_records GENEATE CNAME Records FOR 53 ZONE RECORDSD AND gIVES IT TO 53 ZONE 
# ACM ISSUES THE CERTIFICATE  "cert_validation" 

# ---------------Provider for ACM --------------------

# always US-EAST-1 FOR  ACM/ WAF and CLOUDFRONT / ROUTE 53  global but cdn uses waf

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# ------------Route 53 Hosted Zone ----------------
/*
#removedafter zone var injected as true
# state is removed using this commadn terraform state r
# --- 1. Route 53 Hosted Zone ---

resource "aws_route53_zone" "primary" {
  name = var.domain_name
  count = var.create_route53_zone ? 1 : 0
  tags = {
    Name = "${var.project_name}-primary-zone"
    private_zone = false
  }
}
*/ 


data "aws_route53_zone" "primary_lookup" {
  
  name         = var.domain_name
  #zone var false
  #count = var.create_route53_zone ? 0 : 1

  private_zone = false
  
}
locals {
  #hosted_zone_id = var.create_route53_zone ? aws_route53_zone.primary[0].zone_id : data.aws_route53_zone.primary_lookup[0].zone_id
  hosted_zone_id = data.aws_route53_zone.primary_lookup.zone_id
}
# --- -----------------ACM Certificate---------------------
resource "aws_acm_certificate" "cert" {
  domain_name             = var.domain_name
  
  subject_alternative_names = ["*.${var.domain_name}"] 
  validation_method       = "DNS"
  provider                = aws.us-east-1
  tags = {
    Name = "${var.project_name}-cert"
  }
}

# -------------------------- DNS Validation Records for ACM Certificate-------------- ---
resource "aws_route53_record" "cert_validation_records" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => dvo
    if dvo.domain_name == "*.${var.domain_name}"
  }

  zone_id = local.hosted_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60
}

# --- ------------------------- Certificate Validation (after DNS records fully verified)----------- ---
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  
  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation_records : record.fqdn
    ]
  provider                = aws.us-east-1
}

# -------------Domain Routing (www , root, api) ---------------
resource "aws_route53_record" "root_a" {
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.portfolio_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.portfolio_cdn.hosted_zone_id
    evaluate_target_health = true
  }
  depends_on = [aws_lb.main]
}


resource "aws_route53_record" "www_a" {
  zone_id = local.hosted_zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.portfolio_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.portfolio_cdn.hosted_zone_id
    evaluate_target_health = true
  }
  depends_on = [aws_lb.main]
}

resource "aws_route53_record" "api_a" {
  zone_id = local.hosted_zone_id
  name    = "api.${var.domain_name}"
  type    = "A"
  ###CHANEG IN V2 FOR CDN
  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
  depends_on = [aws_lb.main]
}

