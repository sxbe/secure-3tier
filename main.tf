# ---------------------------------------------------
# Network foundation
# ---------------------------------------------------

# CIS_1_1 — Dedicated VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"  
  enable_dns_hostnames = true            
  tags = {
    Name = "secure-vpc"
  }
}

# ---------- Subnets ----------

# Public subnet (Web) — internet‑facing
resource "aws_subnet" "web" {
  vpc_id                   = aws_vpc.main.id
  cidr_block               = "10.0.1.0/24"   
  map_public_ip_on_launch  = true            
  tags = {
    Name = "web-subnet"     # CIS_2_1
  }
}

# Private subnet (App) — internal backend
resource "aws_subnet" "app" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "app-subnet"
  }
}

# Private subnet (DB) — database layer
resource "aws_subnet" "db" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  tags = {
    Name = "db-subnet"
  }
}

# ---------------------------------------------------
# Internet access for web tier
# ---------------------------------------------------

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "secure-igw" }
}

# Public route table: sends 0.0.0.0/0 → IGW
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "public-rt" }
}

# Attach route table to web subnet
resource "aws_route_table_association" "web_assoc" {
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.public_rt.id
}
