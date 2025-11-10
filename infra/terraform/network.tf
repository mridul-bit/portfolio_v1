# 1. VPC Definition
resource "aws_vpc" "portfolio_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "portfolio-v1-vpc" }
}

# 2. Internet Gateway (for Public Subnets)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.portfolio_vpc.id
  tags = { Name = "portfolio-v1-igw" }
}

# Define Availability Zones (AZs) for High Availability (HA)
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3) # Use 3 AZs
}

# 3. Public Subnets (for ALB and NAT Gateways)
resource "aws_subnet" "public" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.portfolio_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.portfolio_vpc.cidr_block, 8, count.index) # 10.0.0.0/24, 10.0.1.0/24, etc.
  availability_zone = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "portfolio-public-az${count.index}",
    "kubernetes.io/role/elb" = 1 # Tag required for AWS Load Balancer Controller
  }
}

# 4. Private Subnets (for EKS Nodes and RDS)
resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.portfolio_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.portfolio_vpc.cidr_block, 8, count.index + length(local.azs)) # 10.0.3.0/24, etc.
  availability_zone = local.azs[count.index]
  tags = {
    Name = "portfolio-private-az${count.index}",
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned" # Tag required for EKS discovery
  }
}

# 5. Routing Tables (Ensure private traffic goes through NAT for outbound access)
# (NAT Gateway setup is omitted for brevity but is mandatory for true private egress)

# 6. EKS Cluster Definition (Simplified)
resource "aws_eks_cluster" "portfolio_eks" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_master.arn # Requires an IAM role
  vpc_config {
    subnet_ids = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    # The EKS cluster itself should run its ENIs primarily in private subnets for security
    endpoint_private_access = true 
    endpoint_public_access  = true
  }
}