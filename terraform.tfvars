aws_region = "ap-south-1"

ami_id = "ami-094210f044117049d"

vpc_id              = "vpc-0147a5034f0d320d4"
internet_gateway_id = "igw-0df52674b2abbc6f0"

# These are NEW subnets inside the existing VPC.
# Confirm they are unused and within the VPC CIDR before apply.
public_subnet_a_cidr = "10.0.10.0/24"
public_subnet_b_cidr = "10.0.11.0/24"
db_subnet_a_cidr     = "10.0.30.0/24"
db_subnet_b_cidr     = "10.0.31.0/24"

hosted_zone_id = "Z0449630JD1F7M6E1MFF"
brokerone_fqdn = "brokerone.dev.byte2vision.com"

ec2_instance_type       = "t3.small"
db_instance_class       = "db.t4g.micro"
postgres_engine_version = "18.4"

db_name     = "brokerone"
db_username = "brokerone_admin"

codecommit_repo_name = "BrokerOne"
