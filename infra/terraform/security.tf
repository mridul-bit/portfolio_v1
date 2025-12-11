# infra/terraform/security.tf



#----------------------------- ALB Security Group ----------------------------------------

resource "aws_security_group" "alb" {
  vpc_id = aws_vpc.portfolio_vpc.id
  name   = "portfolio-alb-sg"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS access"
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP access"
  }
  

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# -------------------------Fargate Task Security Group -------------------------------
# App waf
resource "aws_security_group" "fargate_tasks" {
  vpc_id = aws_vpc.portfolio_vpc.id
  name   = "portfolio-fargate-tasks-sg"
  
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow app traffic (8000) from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# -------------------------- RDS Security Group----------------------------

resource "aws_security_group" "rds" {
  vpc_id = aws_vpc.portfolio_vpc.id
  name   = "portfolio-rds-sg"


  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.fargate_tasks.id]
    description     = "Allow Postgres traffic from Fargate tasks"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound to AWS services via NAT for maintenance"
  }
}


# -----------------------------VPC Endpoint Security Group -----------------------------------------

resource "aws_security_group" "vpc_endpoint_sg" {
  vpc_id = aws_vpc.portfolio_vpc.id
  name   = "portfolio-vpc-endpoint-sg"
  
  # Ingress: Allow ALL traffic (all ports/protocols) from the Fargate Task Security Group
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.fargate_tasks.id]
    description     = "Allow internal traffic from Fargate tasks to endpoints"
  }
  

}