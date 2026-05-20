# ============================================================================
# VPC Module
# ============================================================================
# Creates a production-grade VPC with public and private subnets across 2 AZs.
#
# WHY this design:
# - Private subnets: EKS nodes and RDS have no public IPs (security)
# - Public subnets: Only ALB and NAT Gateway face the internet
# - NAT Gateway: Allows private subnet resources to pull images, updates
# - Multi-AZ: Required for EKS and RDS high availability
# ============================================================================

# ---------------------------------------------------------------------------
# Data source: Get available AZs in the region
# WHY: Hardcoding AZ names (us-east-1a) breaks if an AZ is unavailable.
# This dynamically picks available AZs.
# ---------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------------
# VPC
# WHY enable_dns_hostnames: Required for EKS and RDS to resolve internal DNS.
# WHY /16 CIDR: Gives us 65,536 IPs — room to grow without re-architecting.
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project}-${var.environment}-vpc"
  }
}

# ---------------------------------------------------------------------------
# Internet Gateway
# WHY: Public subnets need a route to the internet for ALB and NAT Gateway.
# One per VPC — it's a managed, highly available AWS service.
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-${var.environment}-igw"
  }
}

# ---------------------------------------------------------------------------
# Public Subnets (one per AZ)
# WHY map_public_ip_on_launch: Resources here get public IPs (ALB needs this).
# WHY the kubernetes.io tags: Required for AWS Load Balancer Controller to
# discover which subnets to place ALBs in.
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                          = "${var.project}-${var.environment}-public-${count.index + 1}"
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${var.project}-${var.environment}" = "shared"
  }
}

# ---------------------------------------------------------------------------
# Private Subnets (one per AZ)
# WHY no public IP: These are for EKS nodes and databases — no internet exposure.
# WHY the kubernetes.io/role/internal-elb tag: For internal load balancers.
# ---------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                          = "${var.project}-${var.environment}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${var.project}-${var.environment}" = "shared"
  }
}

# ---------------------------------------------------------------------------
# Elastic IP for NAT Gateway
# WHY: NAT Gateway needs a static public IP. If the NAT is recreated,
# the IP stays the same (important for allowlisting with external services).
# ---------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project}-${var.environment}-nat-eip"
  }
}

# ---------------------------------------------------------------------------
# NAT Gateway (in public subnet)
# WHY: Allows private subnet resources (EKS nodes) to reach the internet
# (pull Docker images, OS updates) WITHOUT being reachable FROM the internet.
# WHY only one: Costs ~$32/month. Production would have one per AZ for HA.
# ---------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project}-${var.environment}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------------------
# Route Tables
# WHY separate tables: Public subnets route to IGW, private subnets route to NAT.
# This is the core of network segmentation.
# ---------------------------------------------------------------------------

# Public route table — routes 0.0.0.0/0 to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project}-${var.environment}-public-rt"
  }
}

# Private route table — routes 0.0.0.0/0 to NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project}-${var.environment}-private-rt"
  }
}

# ---------------------------------------------------------------------------
# Route Table Associations
# WHY: A subnet without an explicit association uses the VPC's main route table.
# Explicit associations make the routing clear and auditable.
# ---------------------------------------------------------------------------
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
