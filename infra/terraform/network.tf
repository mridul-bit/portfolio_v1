# infra/terraform/network.tf

# -------------------- VPC -----------------------------------------------
resource "aws_vpc" "portfolio_vpc" {
  cidr_block                   = "10.0.0.0/16"
  instance_tenancy             = "default"
  enable_dns_support           = true
  enable_dns_hostnames         = true
  # enable_generated_ipv6_cidr_block = true # Removed for simplicity 
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ----------------- LOCAL STORING AZ'S ---------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}
locals {
  # Limit to 2 AZs for simplicity and cost saving 
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}


# ---------------Public Subnets (For Load Balancers and NAT Gateway)-----------
resource "aws_subnet" "public" {
  count                     = length(local.azs)
  vpc_id                    = aws_vpc.portfolio_vpc.id
  cidr_block                = cidrsubnet(aws_vpc.portfolio_vpc.cidr_block, 8, count.index)
  availability_zone         = local.azs[count.index]
  map_public_ip_on_launch   = true
  tags = {
    Name = "${var.project_name}-public-subnet-${count.index}"
  }
}

# ---------------------Private Subnets (For private resources)-----------------
resource "aws_subnet" "private" {
  count                     = length(local.azs)
  vpc_id                    = aws_vpc.portfolio_vpc.id
  # index 0 and 1 are used by public
  cidr_block                = cidrsubnet(aws_vpc.portfolio_vpc.cidr_block, 8, count.index + length(local.azs))
  availability_zone         = local.azs[count.index]
  tags = {
    Name = "${var.project_name}-private-subnet-${count.index}"
  }
}

# --- ---------------IGW and NAT Gateway------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.portfolio_vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id 
  tags = {
    Name = "${var.project_name}-nat-gateway"
  }
  depends_on = [aws_internet_gateway.igw, aws_eip.nat_eip]
}

# --------------Route Tables------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.portfolio_vpc.id
  tags = {
    Name = "${var.project_name}-public-rt"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.portfolio_vpc.id
  tags = {
    Name = "${var.project_name}-private-rt"
  }
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

# ------------ Route Table Associations -----------

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# -----------VPC Endpoint for S3 --------------------
# CAN ALSO CREATE VPC FOR OTHER AWS REOURCES - WILL TRY IN NEXT VERSION

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.portfolio_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  
  route_table_ids = [aws_route_table.private.id]
  tags = {
    Name = "${var.project_name}-s3-gateway-endpoint"
  }
}


# --- ------------- RDS Subnet Group------------------------------
resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "${var.project_name}-rds-sng"
  description = "Subnet group for the RDS instance."
  # Use private subnets for the database
  subnet_ids  = aws_subnet.private[*].id
}

# --- -------Outputs ---------------------------
output "vpc_id" {
  description = "The ID of the portfolio VPC."
  value       = aws_vpc.portfolio_vpc.id
}
output "public_subnet_ids" {
  description = "List of Public Subnet IDs for ALB placement."
  value       = aws_subnet.public[*].id
}
output "private_subnet_ids" {
  description = "List of Private Subnet IDs for Fargate/RDS placement."
  value       = aws_subnet.private[*].id
}
output "rds_subnet_group_name" {
  description = "Name of the RDS Subnet Group."
  value       = aws_db_subnet_group.rds_subnet_group.name
}