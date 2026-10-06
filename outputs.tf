output "customer_url" {
  description = "Customer URL through ALB"
  value       = "https://${var.brokerone_fqdn}"
}

output "elastic_ip" {
  value = aws_eip.brokerone.public_ip
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
