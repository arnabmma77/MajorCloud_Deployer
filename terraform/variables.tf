# Primary AWS region
variable "aws_primary_region" {
  description = "Primary AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

# Secondary AWS region for disaster recovery
variable "aws_secondary_region" {
  description = "Secondary AWS region for disaster recovery"
  type        = string
  default     = "us-west-2"
}

# Environment name
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# Application name
variable "app_name" {
  description = "Application name"
  type        = string
  default     = "weather-app"
}

# ECR repository name
variable "ecr_repository_name" {
  description = "ECR repository name for Docker images"
  type        = string
  default     = "weather-app"
}

# ECS cluster name
variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "weather-app-cluster"
}

# ECS service name
variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
  default     = "weather-app-service"
}

# Container port
variable "container_port" {
  description = "Port on which the application container runs"
  type        = number
  default     = 8080
}

# Desired count of ECS tasks
variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

# ECS task CPU
variable "ecs_task_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

# ECS task memory
variable "ecs_task_memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 1024
}

# S3 bucket name for static assets
variable "s3_bucket_name" {
  description = "S3 bucket name for static assets"
  type        = string
  default     = "weather-app-static-assets"
}

# Route 53 domain name (optional)
variable "domain_name" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = ""
}

# OpenWeather API Key
variable "openweather_api_key" {
  description = "OpenWeather API Key for weather data"
  type        = string
  sensitive   = true
  default     = ""
}

# Enable disaster recovery
variable "enable_disaster_recovery" {
  description = "Enable disaster recovery setup with secondary region"
  type        = bool
  default     = true
}

# Health check grace period
variable "health_check_grace_period" {
  description = "Health check grace period in seconds"
  type        = number
  default     = 300
}

# Auto scaling configuration
variable "enable_auto_scaling" {
  description = "Enable auto scaling for ECS service"
  type        = bool
  default     = true
}

variable "auto_scaling_min_capacity" {
  description = "Minimum number of ECS tasks for auto scaling"
  type        = number
  default     = 2
}

variable "auto_scaling_max_capacity" {
  description = "Maximum number of ECS tasks for auto scaling"
  type        = number
  default     = 10
}

# CloudWatch log retention
variable "log_retention_in_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
}

# Common tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "weather-app"
    ManagedBy   = "terraform"
    Repository  = "https://github.com/yourusername/weather-app"
  }
}
