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
