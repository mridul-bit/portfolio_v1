# 1. ALB Security Group (Allows HTTPS from the World)
resource "aws_security_group" "alb" {
  vpc_id = aws_vpc.portfolio_vpc.id
  name   = "portfolio-alb-sg"

  # Inbound: Allow HTTPS (443) from anywhere (0.0.0.0/0)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS access from public internet"
  }
  
  # Inbound: Allow HTTP (80) from anywhere (redirected to HTTPS by ALB)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Outbound: Allow all outbound traffic (standard for ALB)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. EKS Node Group Security Group (Allows traffic only from ALB and itself)
resource "aws_security_group" "eks_nodes" {
  vpc_id = aws_vpc.portfolio_vpc.id
  name   = "portfolio-eks-nodes-sg"
  
  # Inbound: Allow all traffic from the ALB's security group (crucial routing)
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow HTTP/80 from ALB"
  }
  # ... Also needs rules for EKS control plane and internal pod communication (omitted for brevity)
}

# 3. RDS Security Group (Allows traffic only from EKS Nodes)
resource "aws_security_group" "rds" {
  vpc_id = aws_vpc.portfolio_vpc.id
  name   = "portfolio-rds-sg"

  # Inbound: Allow Postgres port (5432) ONLY from the EKS nodes' security group
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
    description     = "Allow Postgres traffic from EKS nodes"
  }
  
  # Outbound: None needed, unless accessing external services.
}