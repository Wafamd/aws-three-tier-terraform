output "app_url" {
  description = "Open this once the target group reports healthy."
  value       = var.certificate_arn == "" ? "http://${aws_lb.this.dns_name}" : "https://${aws_lb.this.dns_name}"
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Use with a Route 53 alias record."
  value       = aws_lb.this.zone_id
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  value = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  value = aws_subnet.data[*].id
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.app.name
}

output "db_endpoint" {
  value = aws_db_instance.this.endpoint
}

output "db_secret_arn" {
  description = "Master credentials. Read with: aws secretsmanager get-secret-value --secret-id <arn>"
  value       = aws_secretsmanager_secret.db.arn
}

output "assets_bucket" {
  value = aws_s3_bucket.assets.bucket
}
