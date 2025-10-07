# Data source for existing hosted zone (if domain is provided)
data "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0
  name  = var.domain_name
}

# Route 53 health check for primary region
resource "aws_route53_health_check" "primary" {
  count = var.domain_name != "" && var.enable_disaster_recovery ? 1 : 0

  fqdn                            = aws_lb.main.dns_name
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/health"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_logs_region          = data.aws_region.current.name
  cloudwatch_alarm_region         = data.aws_region.current.name
  insufficient_data_health_status = "Failure"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-health-check-primary"
  })
}

# Route 53 health check for secondary region (placeholder)
resource "aws_route53_health_check" "secondary" {
  count = var.domain_name != "" && var.enable_disaster_recovery ? 1 : 0

  # Note: This assumes you have a load balancer in the secondary region
  # You would need to create ECS infrastructure in secondary region too
  fqdn                            = "secondary-${aws_lb.main.dns_name}"  # Placeholder
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/health"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_logs_region          = var.aws_secondary_region
  cloudwatch_alarm_region         = var.aws_secondary_region
  insufficient_data_health_status = "Failure"

  tags = merge(local.common_tags, {
    Name   = "${local.name_prefix}-health-check-secondary"
    Region = "secondary"
  })
}

# Route 53 record for primary region (weighted routing)
resource "aws_route53_record" "primary" {
  count = var.domain_name != "" ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  set_identifier = "primary"
  
  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = var.enable_disaster_recovery ? aws_route53_health_check.primary[0].id : null

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Route 53 record for secondary region (disaster recovery)
resource "aws_route53_record" "secondary" {
  count = var.domain_name != "" && var.enable_disaster_recovery ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  set_identifier = "secondary"
  
  failover_routing_policy {
    type = "SECONDARY"
  }

  # Note: This assumes you have a load balancer in the secondary region
  alias {
    name                   = "secondary-${aws_lb.main.dns_name}"  # Placeholder
    zone_id                = aws_lb.main.zone_id                 # Would need actual secondary LB zone
    evaluate_target_health = true
  }
}

# Route 53 record for www subdomain
resource "aws_route53_record" "www" {
  count = var.domain_name != "" ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.domain_name]
}

# CloudWatch alarm for health check failures
resource "aws_cloudwatch_metric_alarm" "health_check_primary" {
  count = var.domain_name != "" && var.enable_disaster_recovery ? 1 : 0

  alarm_name          = "${local.name_prefix}-health-check-primary-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This metric monitors the health check for primary region"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]
  ok_actions          = [aws_sns_topic.alerts[0].arn]
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-health-check-alarm-primary"
  })
}

# SNS topic for health check alerts
resource "aws_sns_topic" "alerts" {
  count = var.domain_name != "" && var.enable_disaster_recovery ? 1 : 0
  
  name = "${local.name_prefix}-health-alerts"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-health-alerts"
  })
}

# SNS topic policy
resource "aws_sns_topic_policy" "alerts" {
  count = var.domain_name != "" && var.enable_disaster_recovery ? 1 : 0
  
  arn = aws_sns_topic.alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarmsToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts[0].arn
      }
    ]
  })
}

# Example SNS subscription (email notification)
# Note: You would need to confirm the subscription manually
resource "aws_sns_topic_subscription" "email_alerts" {
  count = var.domain_name != "" && var.enable_disaster_recovery ? 1 : 0
  
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = "admin@${var.domain_name}"  # Change to actual email
}

# Secondary region infrastructure (placeholder for complete DR setup)
# Note: For a complete disaster recovery setup, you would need to:
# 1. Create another provider for the secondary region
# 2. Duplicate the ECS, ALB, and related infrastructure
# 3. Set up cross-region ECR replication
# 4. Configure database replication if using RDS

# Example secondary region ECS cluster (placeholder)
resource "aws_ecs_cluster" "secondary" {
  count = var.enable_disaster_recovery ? 1 : 0

  provider = aws.secondary
  name     = "${var.ecs_cluster_name}-secondary"

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = false
        cloud_watch_log_group_name     = "/ecs/${local.name_prefix}-secondary"
      }
    }
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.common_tags, {
    Name   = "${local.name_prefix}-cluster-secondary"
    Region = "secondary"
  })
}
