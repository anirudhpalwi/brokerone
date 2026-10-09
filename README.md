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

Source: Scrut_AWS_Findings_by_Project.xlsx (37 BrokerOne findings). The 27 that
remained after the first round are tracked in `Brokerone fixes - status.xlsx`
(OneDrive). Status below was checked against live AWS on 8 Oct 2026, with
`terraform plan` showing no pending changes.

### Round 1: fixed (10 findings)

| Finding | Resource | Change |
|---|---|---|
| S3 bucket allowing cleartext | brokerone-dev-filestorage | Bucket policy denies `aws:SecureTransport=false` (s3_filestorage.tf) |
| S3 bucket versioning | brokerone-dev-filestorage | Versioning on |
| S3 bucket logging | brokerone-dev-filestorage | Server access logs go to the log bucket (`s3-access/`) |
| Drop Invalid Header Fields Disabled | brokerone-dev-alb | `drop_invalid_header_fields = true` |
| ELBv2 no access logs | brokerone-dev-alb | Access logs go to the log bucket (`alb/`) |
| ELBv2 deletion protection | brokerone-dev-alb | `enable_deletion_protection = true` |
| IAM role with inline policies | brokerone-dev-ec2-role | All inline policies converted to customer-managed policies |
| RDS backup retention period | brokerone-dev | `backup_retention_period = 7` |
| VPC subnet flow log (7 subnets) | vpc-0147a5034f0d320d4 | VPC-level flow logs to the log bucket (`vpc-flow-logs/`) |
| Unused Security Group | sg-085daf2d7824de48a | Deleted |

### Round 2: status of the remaining 27

**Done: 21**

| # | Finding | Resource | Change |
|---|---|---|---|
| 1 | Drop Invalid Header Fields Disabled | brokerone-dev-alb | `drop_invalid_header_fields = true` (alb_dns.tf) |
| 2 | ELBv2 no access logs | brokerone-dev-alb | Access logs to `brokerone-dev-logs-<account-id>/alb/` |
| 3 | RDS backup retention period | brokerone-dev | `backup_retention_period = 7` (rds.tf) |
| 4-6 | IAM role with inline policies | brokerone-dev-ecs-task, brokerone-dev-ecs-task-exec, brokerone-dev-github-deploy | Roles deleted. They belonged to the old ECS / GitHub Actions setup in us-east-1, which had been removed. The shared GitHub OIDC provider was kept (used by insqtop roles). |
| 7 | ELBv2 deletion protection | brokerone-dev-alb | `enable_deletion_protection = true` |
| 12, 13, 19, 20 | NACL allows all egress / ingress | brokerone-db-subnet-group (10.0.3.0/24), brokerone-db-subnet-group 1b (10.0.4.0/24) | Empty subnets deleted (not managed here) |
| 14, 15, 21, 22 | NACL allows all egress / ingress | brokerone-dev-db-a, brokerone-dev-db-b | Custom NACL `brokerone-dev-db-nacl` (network.tf): only PostgreSQL 5432 in from the public subnets, replies 1024-65535 back to them |
| 16, 17, 23, 24 | NACL allows all egress / ingress | brokerone-dev-public-a, brokerone-dev-public-b | Custom NACL `brokerone-dev-public-nacl` (network.tf): 80/443 in from the internet, 5192 between ALB and app, 5432 to the DB subnets, 80/443 out, reply ports 1024-65535 |
| 26 | RDS instance single AZ | brokerone-dev | `multi_az = true` (rds.tf). Roughly doubles RDS cost. |
| 27 | S3 bucket logging | brokerone-dev-logs-<account-id> | Server access logs go to the new bucket `brokerone-dev-logs-access-<account-id>` under `brokerone-dev-logs/` (logging.tf) |

**Pending: 4**

| # | Finding | Resource | What is left |
|---|---|---|---|
| 10 | Bucket without MFA Delete | brokerone-dev-filestorage | Lifecycle rule already removed (AWS does not allow lifecycle rules with MFA Delete). The root user must enable MFA Delete in CloudShell (see below). |
| 11 | Bucket without MFA Delete | brokerone-dev-logs-<account-id> | Same as #10. |
| 18, 25 | NACL allows all egress / ingress | brokerone-public-1a (holds brokerone-static-ip-box) | Not managed here. Create `brokerone-proxy-nacl` in the console or CLI: inbound 22 and 3128 from the office IP (/32) plus replies 1024-65535; outbound 80/443 plus replies to the office IP (/32). Confirm the proxy needs no other outbound ports first. |

**Decision needed: 2**

| # | Finding | Resource | Notes |
|---|---|---|---|
| 8 | Instance with a Public IP Address | brokerone-dev-ec2 | Needed for outbound access because the VPC has no NAT gateway. Inbound is 5192 from the ALB SG only, no SSH. Accept in Scrut with this reason, or add a NAT gateway / VPC endpoints (replaces the instance). |
| 9 | Instance with a Public IP Address | brokerone-static-ip-box | Proxy/SSH box whose purpose is a fixed public IP; access limited to the office IP. Not managed here. Likely accept in Scrut. |

### Enabling MFA Delete (#10, #11)

Sign in as the root user (with MFA), open CloudShell in ap-south-1, and run for
each bucket (a fresh MFA code each time):

    aws iam list-mfa-devices --query "MFADevices[].SerialNumber" --output text
    aws s3api put-bucket-versioning --bucket <bucket> \
      --versioning-configuration Status=Enabled,MFADelete=Enabled \
      --mfa "<root-mfa-arn> <6-digit code>"

Do the same for `brokerone-dev-logs-access-<account-id>`. Then run
`terraform plan`. If it tries to turn MFA Delete off, add
`mfa_delete = "Enabled"` to the matching `aws_s3_bucket_versioning` resource.

The three buckets have no lifecycle rules, so old versions and logs are kept
until the root user deletes them with an MFA code. Storage cost grows over time.

### Follow-ups (not in the Scrut list)

- `brokerone-dev-logs-access-<account-id>` has no logging of its own. Add S3
  data events for it to the CloudTrail trail `account-trail`.
- GitHub repo `anirudhpalwi/brokerone` is public. Make it private.
- RDS deletion protection is off (`deletion_protection = false` in rds.tf).
- Terraform state is local (OneDrive) and contains the DB password. Move it to an
  encrypted S3 backend with locking.
- The DB password is never rotated; the app reads it from
  `/etc/brokerone/brokerone.env`.

### Operational notes

1. ALB deletion protection blocks `terraform destroy`. Set
   `enable_deletion_protection = false` and apply before destroying.
2. The ALB drops request headers whose names are not `[-A-Za-z0-9]+` (for
   example, names with underscores).
3. NACLs are stateless. If a new outbound connection from the app is blocked
   (a new port or service), add both the outbound rule and the matching reply
   rule in network.tf. To roll back quickly, re-associate the subnets with the
   default NACL `acl-0e8bf3970ea6e512a`.
4. brokerone-dev-filestorage is not created by Terraform. The bucket policy and
   logging resources here replace whatever is set on the bucket.
