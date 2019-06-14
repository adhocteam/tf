### Creates the network infrastructure to include:
###  - VPC
###  - Subnets
###  - Availability Zones
###  - Internet Gateways
###  - Elastic IPs
###  - NAT Instances
###  - VPC Endpoints

terraform {
  required_version = ">= 0.12"
}

####
# VPC with internal DNS support
####

resource "aws_vpc" "primary" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true # necessary for internal DNS support
  enable_dns_support   = true

  tags = {
    env       = var.env
    terraform = "true"
  }
}

resource "aws_route53_zone" "internal" {
  name    = "${var.env}.local"
  comment = "${var.env} internal DNS"

  vpc {
    vpc_id = aws_vpc.primary.id
  }

  tags = {
    env       = var.env
    terraform = "true"
    name      = "internal-dns"
  }
}

####
# Network Subnets
####

# Create 3 private subnets spead across 3 AZs of size /18 (~16k addresses) that can
# egress traffic to the internet via NAT gateways
resource "aws_subnet" "application" {
  count             = 3
  vpc_id            = aws_vpc.primary.id
  cidr_block        = cidrsubnet(var.cidr, 2, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    env       = var.env
    terraform = "true"
    name      = "app-sub-${count.index}"
  }
}

# We subdivide the remaining /18 block into 8 pieces (/21 blocks or ~2k addresses), using 6 for data and public subnets
# and leaving 2 (a /20 block or 4k addresses) free for future use

# Use the first 3 /21 blocks for public subnets (with full internet accesss via an internet gateway)
resource "aws_subnet" "public" {
  count             = 3
  vpc_id            = aws_vpc.primary.id
  cidr_block        = cidrsubnet(cidrsubnet(var.cidr, 2, 3), 3, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    env       = var.env
    terraform = "true"
    name      = "public-sub-${count.index}"
  }
}

# Use the next 3 /21 blocks for data subnets for RDS
resource "aws_subnet" "data" {
  count             = 3
  vpc_id            = aws_vpc.primary.id
  cidr_block        = cidrsubnet(cidrsubnet(var.cidr, 2, 3), 3, count.index + 3)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    env       = var.env
    terraform = "true"
    name      = "data-sub-${count.index}"
  }
}

####
# Create route for public traffic to the internet
####

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.primary.id

  tags = {
    env       = var.env
    terraform = "true"
    name      = "main-internet-gateway"
  }
}

resource "aws_route_table" "public_igw" {
  vpc_id = aws_vpc.primary.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    env       = var.env
    terraform = "true"
    name      = "route-to-internet-gateway"
  }
}

resource "aws_route_table_association" "public_with_igw" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_igw.id
}

####
# Create route for application egress traffic to the internet via AZ specific NAT instances
####

resource "aws_eip" "nats" {
  count = 3
  vpc   = true

  # Note: EIP may require IGW to exist prior to association.
  # Use depends_on to set an explicit dependency on the IGW.
  # https://www.terraform.io/docs/providers/aws/r/eip.html
  depends_on = [aws_internet_gateway.igw]

  tags = {
    env       = var.env
    terraform = "true"
    name      = "nat-ip-${count.index}"
  }
}

resource "aws_nat_gateway" "nats" {
  count         = 3
  allocation_id = aws_eip.nats[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    env       = var.env
    terraform = "true"
    name      = "nat-${count.index}"
  }
}

resource "aws_route_table" "nats" {
  count  = 3
  vpc_id = aws_vpc.primary.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nats[count.index].id
  }

  tags = {
    env       = var.env
    terraform = "true"
    name      = "route-to-nat-${count.index}"
  }
}

resource "aws_route_table_association" "app_with_nat" {
  count          = 3
  subnet_id      = aws_subnet.application[count.index].id
  route_table_id = aws_route_table.nats[count.index].id
}

######
# VPC Endpoints
######

locals {
  route_tables = concat(aws_route_table.public_igw, aws_route_table.nats)
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.primary.id
  service_name    = "com.amazonaws.${data.aws_region.current.name}.s3"
  route_table_ids = local.route_tables[*].id
}

