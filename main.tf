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
    Name = "web-subnet" # CIS_2_1 — Separate public subnet
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

# Private subnet (DB) — first AZ
resource "aws_subnet" "db" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  tags = {
    Name = "db-subnet"
  }
}

# Private subnet (DB‑B) second AZ
resource "aws_subnet" "db_b" { # CIS_2_4 — Multi‑AZ subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1a"
  tags              = { 
    Name = "db-subnet-b" 
    }
}

# ---------------------------------------------------
# Internet access for web tier
# ---------------------------------------------------

# CIS_3_1 — Attach single IGW to VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "secure-igw" }
}

# Public route table: sends 0.0.0.0/0 → IGW
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0" # CIS_3_3 — Explicit 0.0.0.0/0 route via IGW
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "public-rt" }
}

# CIS_3_3 — Associate public RT only with web subnet
resource "aws_route_table_association" "web_assoc" {
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.public_rt.id
}

# ---------------------------------------------------
# Security Groups (firewall rules)
# ---------------------------------------------------

# CIS_4_1 — Restrict inbound traffic with SGs
resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80 # CIS_4_3 — 80 open to internet
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443 # CIS_4_3
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

# App SG — only web‑sg can call port 5000
resource "aws_security_group" "app_sg" { # CIS_4_1
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

# DB SG — only app‑sg can reach MySQL
resource "aws_security_group" "db_sg" { # CIS_4_1
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

# ---------------------------------------------------
# DB subnet group (uses the private DB subnet)
# ---------------------------------------------------
resource "aws_db_subnet_group" "db_subnets" {
  name       = "db-subnet-group"
  subnet_ids = [
    aws_subnet.db.id,     # us-east-1f
    aws_subnet.db_b.id    # us-east-1a
  ]

  tags = { Name = "db-subnet-group" }
}

# ---------------------------------------------------
# RDS MySQL instance (free‑tier size)
# ---------------------------------------------------
resource "aws_db_instance" "mysql" {
  identifier              = "secure-mysql"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"   # free‑tier
  allocated_storage       = 5               # GB
  username                = "admin"
  password                = "Passw0rd123!"  # demo; rotate in Secrets Manager for real use
  db_subnet_group_name    = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  skip_final_snapshot     = true            
  backup_retention_period = 7               
  deletion_protection      = false          

  tags = { Name = "db-mysql" }
}

# ---------------------------------------------------
# Outputs
# ---------------------------------------------------
output "db_endpoint" {
  value = aws_db_instance.mysql.address
}

# ---------------------------------------------------
# CloudTrail (multi‑region) CIS_2_1 / CIS_2_2
# ---------------------------------------------------
resource "random_id" "rand" {
  byte_length = 4
}

resource "aws_s3_bucket" "trail_bucket" {
  bucket = "secure3tier-trail-${random_id.rand.hex}"
  force_destroy = true                     
}

resource "aws_cloudtrail" "main" {
  name                          = "ct-all"
  s3_bucket_name                = aws_s3_bucket.trail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true # CIS_2_1 — CloudTrail in all regions
  enable_log_file_validation    = true # CIS_2_2 — Log file validation
  tags = { Name = "cloudtrail-all" }
}

# ---------------------------------------------------
# VPC Flow Logs (web subnet) CIS_3_2
# ---------------------------------------------------
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/vpc/flow"
  retention_in_days = 7                
}

resource "aws_flow_log" "web" {
  subnet_id       = aws_subnet.web.id
  log_destination = aws_cloudwatch_log_group.flow.arn
  traffic_type    = "ALL" # CIS_3_2 — Capture ACCEPT+REJECT
  log_format      = "${version} ${interface-id} ${srcaddr} ${dstaddr} ${dstport} ${action}"
}
