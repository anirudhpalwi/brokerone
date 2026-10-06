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

## Scrut security findings (BrokerOne)

Source: Scrut_AWS_Findings_by_Project.xlsx (37 BrokerOne findings).

Fixed in this Terraform:

| Finding | Resource | Change |
|---|---|---|
| S3 bucket allowing cleartext | brokerone-dev-filestorage | Bucket policy denies `aws:SecureTransport=false` (s3_filestorage.tf) |
| S3 bucket versioning | brokerone-dev-filestorage | Versioning on, noncurrent versions expire after 30 days |
| S3 bucket logging | brokerone-dev-filestorage | Server access logs go to the log bucket (`s3-access/`) |
| Drop Invalid Header Fields Disabled | brokerone-dev-alb | `drop_invalid_header_fields = true` |
| ELBv2 no access logs | brokerone-dev-alb | Access logs go to the log bucket (`alb/`) |
| ELBv2 deletion protection | brokerone-dev-alb | `enable_deletion_protection = true` |
| IAM role with inline policies | brokerone-dev-ec2-role | All inline policies converted to customer-managed policies |
| RDS backup retention period | brokerone-dev | `backup_retention_period = 7` |
| VPC subnet flow log (7 subnets) | vpc-0147a5034f0d320d4 | VPC-level flow logs to the log bucket (`vpc-flow-logs/`) |

New log bucket: `brokerone-dev-logs-<account-id>` (SSE-S3, TLS-only, public access
blocked, versioned, logs expire after 90 days). See logging.tf.

Accepted risk / documented exception:

- Instance with a Public IP Address (brokerone-dev-ec2): it is needed for outbound
  access because the VPC has no NAT gateway. Inbound is 5192 from the ALB SG only.
- RDS instance single AZ: accepted for DEV because of cost.
- Bucket without MFA Delete: root-only setting; accepted.
- NACL allows all ingress/egress (7 subnets): default NACL, security groups are the
  primary control.

Not managed in this repo (fix in the AWS console or the owning repo):

- brokerone-static-ip-box: Instance with a Public IP Address.
- brokerone-dev-ecs-task, brokerone-dev-ecs-task-exec, brokerone-dev-github-deploy:
  IAM role with inline policies.
- BrokerOne RDS SG (sg-085daf2d7824de48a): Unused Security Group. Confirm and delete.

Before the first apply of these changes:

1. brokerone-dev-filestorage is not created by Terraform. The bucket policy,
   lifecycle and logging resources REPLACE whatever is set on the bucket now. Check:

       aws s3api get-bucket-policy --bucket brokerone-dev-filestorage
       aws s3api get-bucket-lifecycle-configuration --bucket brokerone-dev-filestorage
       aws s3api get-bucket-logging --bucket brokerone-dev-filestorage

   If any of these return existing settings, add them to s3_filestorage.tf first.
2. ALB deletion protection blocks `terraform destroy`. Set
   `enable_deletion_protection = false` and apply before destroying.
3. The ALB now drops request headers whose names are not `[-A-Za-z0-9]+`
   (for example, names with underscores). Confirm the app does not rely on any.
4. Moving from inline to managed IAM policies can leave the EC2 role without
   permissions for a few seconds during apply.
