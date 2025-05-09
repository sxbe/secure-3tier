| CIS Control | Terraform snippet |
| --- | --- |
| CIS_1_1 | `# CIS_1_1 — Dedicated VPC` |
| CIS_2_1 | `Name = "web-subnet" # CIS_2_1 — Separate public subnet` |
| CIS_2_4 | `resource "aws_subnet" "db_b" { # CIS_2_4 — Multi‑AZ subnets` |
| CIS_3_1 | `# CIS_3_1 — Attach single IGW to VPC` |
| CIS_3_3 | `cidr_block = "0.0.0.0/0" # CIS_3_3 — Explicit 0.0.0.0/0 route via IGW` |
| CIS_3_3 | `# CIS_3_3 — Associate public RT only with web subnet` |
| CIS_4_1 | `# CIS_4_1 — Restrict inbound traffic with SGs` |
| CIS_4_3 | `from_port   = 80 # CIS_4_3 — 80 open to internet` |
| CIS_4_3 | `from_port   = 443 # CIS_4_3` |
| CIS_4_1 | `resource "aws_security_group" "app_sg" { # CIS_4_1` |
| CIS_4_1 | `resource "aws_security_group" "db_sg" { # CIS_4_1` |
| CIS_2_1 | `is_multi_region_trail         = true # CIS_2_1 — CloudTrail in all regions` |
| CIS_2_2 | `enable_log_file_validation    = true # CIS_2_2 — Log file validation` |
| CIS_3_2 | `traffic_type    = "ALL" # CIS_3_2 — Capture ACCEPT+REJECT` |