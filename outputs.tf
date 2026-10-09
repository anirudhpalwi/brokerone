output "customer_url" {
  description = "Customer URL through ALB"
  value       = "https://${var.brokerone_fqdn}"
}

output "ec2_private_ip" {
  value = aws_instance.brokerone.private_ip
}

output "nat_public_ip" {
  description = "Outbound IP of the app server (NAT gateway)"
  value       = aws_eip.nat.public_ip
}

output "private_subnet_a_id" {
  value = aws_subnet.private_a.id
}

output "private_subnet_b_id" {
  value = aws_subnet.private_b.id
}

output "ec2_instance_id" {
  value = aws_instance.brokerone.id
}

output "public_subnet_a_id" {
  value = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  value = aws_subnet.public_b.id
}

output "db_subnet_a_id" {
  value = aws_subnet.db_a.id
}

output "db_subnet_b_id" {
  value = aws_subnet.db_b.id
}

output "alb_dns_name" {
  value = aws_lb.brokerone.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.brokerone.address
}

output "db_secret_name" {
  value = aws_secretsmanager_secret.db.name
}

output "log_bucket_name" {
  value = aws_s3_bucket.logs.id
}
