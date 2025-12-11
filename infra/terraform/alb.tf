# infra/terraform/alb.tf

# -------------------------------------------------------------
# 1. Application Load Balancer (ALB)
# -------------------------------------------------------------
resource "aws_lb" "main" {
  name                      = "portfolio-main-alb"
  internal                  = false
  load_balancer_type        = "application"
  
  # Reference the public subnet IDs
  subnets                   = aws_subnet.public[*].id
  
  # ALB uses its public security group
  security_groups           = [aws_security_group.alb.id]
  ip_address_type           = "ipv4"
  
  enable_deletion_protection = false
  tags = { Name = "portfolio-main-alb" }
  depends_on = [aws_security_group.alb]
}

# -------------------------------------------------------------
# 2. Target Group (TG) - Defined here for clean reference in ECS/Listener
# -------------------------------------------------------------
resource "aws_lb_target_group" "fargate" {
  name        = "portfolio-fargate-tg"
  port        = 8000 # The container port the ECS task is listening on.
  protocol    = "HTTP"
  vpc_id      = aws_vpc.portfolio_vpc.id
  target_type = "ip" # Required for Fargate

  health_check {
    enabled             = true
    path                = "/health/ready" # Standard health check endpoint (MUST be implemented in backend)
    protocol            = "HTTP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }
  
  tags = { Name = "portfolio-fargate-tg" }
}

# -------------------------------------------------------------
# 3. ALB Listeners (HTTP and HTTPS)
# -------------------------------------------------------------
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  # CRITICAL FIX: The certificate ARN comes from the validation resource in route53.tf
  certificate_arn   = aws_acm_certificate_validation.cert_validation.certificate_arn 
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fargate.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# -------------------------------------------------------------
# Outputs (Essential for inter-file references)
# -------------------------------------------------------------
output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "fargate_target_group_arn" {
  description = "The ARN of the Fargate Target Group."
  value       = aws_lb_target_group.fargate.arn
}