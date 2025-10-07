# ECR Repository URL
output "ecr_repository_url" {
  description = "ECR repository URL for Docker images"
  value       = aws_ecr_repository.app.repository_url
}

# ECR Repository Name
output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.app.name
}

# ECS Cluster Name
output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

# ECS Service Name
output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

# Application Load Balancer DNS Name
output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

# Application Load Balancer Zone ID
output "alb_zone_id" {
  description = "Application Load Balancer Zone ID"
  value       = aws_lb.main.zone_id
}

# Application URL
output "app_url" {
  description = "Application URL"
  value       = "http://${aws_lb.main.dns_name}"
}

# S3 Bucket Name for Static Assets
output "s3_bucket_name" {
  description = "S3 bucket name for static assets"
  value       = aws_s3_bucket.static_assets.bucket
}

# S3 Bucket ARN for Static Assets
output "s3_bucket_arn" {
  description = "S3 bucket ARN for static assets"
  value       = aws_s3_bucket.static_assets.arn
}

# CloudFront Distribution Domain Name
output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.static_assets.domain_name
}

# CloudFront Distribution ID
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.static_assets.id
}

# VPC ID
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

# Public Subnet IDs
output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

# Security Group ID for ALB
output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = aws_security_group.alb.id
}

# Security Group ID for ECS Tasks
output "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}

# CloudWatch Log Group Name
output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.app.name
}

# Terraform State Bucket Name
output "terraform_state_bucket_name" {
  description = "Terraform state S3 bucket name"
  value       = aws_s3_bucket.terraform_state.bucket
}

# DynamoDB State Lock Table Name
output "terraform_state_lock_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  value       = aws_dynamodb_table.terraform_state_lock.name
}

# Route 53 Health Check IDs (if domain is configured)
output "route53_health_check_primary_id" {
  description = "Route 53 health check ID for primary region"
  value       = var.domain_name != "" && var.enable_disaster_recovery ? aws_route53_health_check.primary[0].id : null
}

output "route53_health_check_secondary_id" {
  description = "Route 53 health check ID for secondary region"
  value       = var.domain_name != "" && var.enable_disaster_recovery ? aws_route53_health_check.secondary[0].id : null
}

# SNS Topic ARN for Alerts
output "sns_alerts_topic_arn" {
  description = "SNS topic ARN for health check alerts"
  value       = var.domain_name != "" && var.enable_disaster_recovery ? aws_sns_topic.alerts[0].arn : null
}

# Custom Domain URL (if configured)
output "custom_domain_url" {
  description = "Custom domain URL (if configured)"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : null
}

# ECS Task Definition ARN
output "ecs_task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.app.arn
}

# ECS Task Execution Role ARN
output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

# ECS Task Role ARN
output "ecs_task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.ecs_task.arn
}

# Auto Scaling Target ARN
output "auto_scaling_target_arn" {
  description = "Auto scaling target ARN"
  value       = var.enable_auto_scaling ? aws_appautoscaling_target.ecs_target[0].arn : null
}

# Secondary Region Resources (if enabled)
output "secondary_region_ecr_repository_url" {
  description = "ECR repository URL in secondary region"
  value       = var.enable_disaster_recovery ? aws_ecr_repository.app_secondary[0].repository_url : null
}

output "secondary_region_ecs_cluster_name" {
  description = "ECS cluster name in secondary region"
  value       = var.enable_disaster_recovery ? aws_ecs_cluster.secondary[0].name : null
}

# Environment Information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region_primary" {
  description = "Primary AWS region"
  value       = var.aws_primary_region
}

output "aws_region_secondary" {
  description = "Secondary AWS region"
  value       = var.aws_secondary_region
}

# Account Information
output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

# Secrets Manager Secret ARN
output "openweather_api_key_secret_arn" {
  description = "Secrets Manager ARN for OpenWeather API key"
  value       = var.openweather_api_key != "" ? aws_secretsmanager_secret.openweather_api_key[0].arn : null
}

# SSL Certificate ARNs
output "acm_certificate_arn" {
  description = "ACM certificate ARN for primary region"
  value       = var.domain_name != "" ? aws_acm_certificate.main[0].arn : null
}

output "acm_certificate_arn_secondary" {
  description = "ACM certificate ARN for secondary region"
  value       = var.domain_name != "" && var.enable_disaster_recovery ? aws_acm_certificate.secondary[0].arn : null
}

# HTTPS Configuration
output "https_enabled" {
  description = "Whether HTTPS is enabled"
  value       = var.domain_name != "" ? true : false
}

output "app_url_https" {
  description = "Application HTTPS URL (if custom domain configured)"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : null
}
