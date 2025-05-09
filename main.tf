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
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "web-subnet" # CIS_2_1
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

# ---------------------------------------------------
# Security Groups (firewall rules)
# ---------------------------------------------------

# Web SG
resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# App SG
resource "aws_security_group" "app_sg" {
  name   = "app-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB SG
resource "aws_security_group" "db_sg" {
  name   = "db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------
# Web-tier EC2 instance
# ---------------------------------------------------

# Latest Amazon Linux 2023 (x86_64) AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]   # looser match
  }
}

# EC2 instance in public subnet
resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"                 # free‑tier size
  subnet_id                   = aws_subnet.web.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = "web-key"

  user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              echo "Hello from Secure Web Tier" > /var/www/html/index.html
              systemctl enable --now httpd
              EOF

  tags = { Name = "web-ec2" }
}

# Output public IP for testing
output "web_public_ip" {
  value = aws_instance.web.public_ip
}

# ---------------------------------------------------
# App‑tier EC2 (private subnet)
# ---------------------------------------------------
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id   # same AMI data source used for web
  instance_type          = "t2.micro"                     # free‑tier
  subnet_id              = aws_subnet.app.id              # PRIVATE subnet
  vpc_security_group_ids = [aws_security_group.app_sg.id] # only port 5000 from web SG
  key_name               = "web-key"

  user_data = <<-EOF
              #!/bin/bash
              # very simple Flask app on port 5000
              yum install -y python3
              pip3 install flask
              cat > /tmp/app.py <<'PY'
              from flask import Flask
              app = Flask(__name__)
              @app.route('/')
              def hello():
                  return 'Hello from App'
              app.run(host='0.0.0.0', port=5000)
              PY
              nohup python3 /tmp/app.py &
              EOF

  tags = { Name = "app-ec2" }
}

# Output app's private IP for testing
output "app_private_ip" {
  value = aws_instance.app.private_ip
}
