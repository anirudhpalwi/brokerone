variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_id" {
  description = "Existing BrokerOne VPC"
  type        = string
  default     = "vpc-0147a5034f0d320d4"
}

variable "internet_gateway_id" {
  description = "Existing internet gateway attached to the VPC"
  type        = string
  default     = "igw-0df52674b2abbc6f0"
}

variable "public_subnet_a_cidr" {
  description = "New public subnet A CIDR"
  type        = string
  default     = "10.0.10.0/24"
}

variable "public_subnet_b_cidr" {
  description = "New public subnet B CIDR"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet_a_cidr" {
  description = "Private app subnet A CIDR (EC2, no public IP)"
  type        = string
  default     = "10.0.20.0/24"
}

variable "private_subnet_b_cidr" {
  description = "Private app subnet B CIDR"
  type        = string
  default     = "10.0.21.0/24"
}

variable "db_subnet_a_cidr" {
  description = "New private DB subnet A CIDR"
  type        = string
  default     = "10.0.30.0/24"
}

variable "db_subnet_b_cidr" {
  description = "New private DB subnet B CIDR"
  type        = string
  default     = "10.0.31.0/24"
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for byte2vision.com"
  type        = string
  default     = "Z0449630JD1F7M6E1MFF"
}

variable "brokerone_fqdn" {
  description = "BrokerOne customer DNS name"
  type        = string
  default     = "brokerone.dev.byte2vision.com"
}

variable "ec2_instance_type" {
  description = "BrokerOne EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "db_instance_class" {
  description = "BrokerOne RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "postgres_engine_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "18.3"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "brokerone"
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "brokerone_admin"
}

variable "codecommit_repo_name" {
  description = "CodeCommit repository name"
  type        = string
  default     = "BrokerOne"
}

variable "ami_id" {
  description = "Pinned AMI for BrokerOne EC2"
  type        = string
  default     = "ami-094210f044117049d"
}