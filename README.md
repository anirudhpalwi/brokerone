# BrokerOne DEV Terraform - Corrected

This package uses only the existing VPC:

- VPC: vpc-0147a5034f0d320d4
- Existing IGW: igw-0df52674b2abbc6f0

It creates new BrokerOne-specific subnets:

- Public A: 10.0.10.0/24
- Public B: 10.0.11.0/24
- DB A: 10.0.30.0/24
- DB B: 10.0.31.0/24

Architecture:

Customer:
Route53 -> ACM -> ALB :443 -> EC2 Node.js :5192 -> private RDS PostgreSQL

Technical team:
Elastic-IP:5192 -> EC2 Node.js :5192

Before apply:

1. Confirm the four new CIDRs are free and inside the VPC CIDR.
2. Copy terraform.tfvars.example to terraform.tfvars.
3. Change team_access_cidr to your office/VPN/public CIDR.

Commands:

terraform fmt -recursive
terraform init
terraform validate
terraform plan

Review the plan before running:

terraform apply

Notes:
- Existing subnets are not used.
- Existing subnet route tables are not modified.
- ALB uses two new public subnets in different Availability Zones.
- RDS uses two new private DB subnets.
- DB subnets have no default internet route.
- Port 5192 is open only from the ALB SG and team_access_cidr.
- No SSH rule is created; use SSM Session Manager.
