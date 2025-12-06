# Data source for existing hosted zone (if domain is provided)
data "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0
  name  = var.domain_name
}

# Route 53 health check for primary region
resource "aws_route53_health_check" "primary" {
  count = var.domain_name != "" && var.enable_disaster_recovery ? 1 : 0

  fqdn              = data.aws_lb.main.dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  # Valid values: Healthy | Unhealthy | LastKnownStatus
  insufficient_data_health_status = "LastKnownStatus"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-health-check-primary"
  })
}

# Route 53 health check for secondary region (placeholder)
resource "aws_route53_health_check" "secondary" {
  count = var.domain_name != "" && var.enable_disaster_recovery ? 1 : 0

  # Note: adjust this fqdn to the real secondary load balancer DNS if available
  fqdn              = "secondary-${data.aws_lb.main.dns_name}"
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  insufficient_data_health_status = "LastKnownStatus"

  tags = merge(local.common_tags, {
    Name   = "${local.name_prefix}-health-check-secondary"
    Region = "secondary"
  })
}

# Route 53 record for primary region (failover PRIMARY)
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
    name                   = data.aws_lb.main.dns_name
    zone_id                = data.aws_lb.main.zone_id
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
    name                   = "secondary-${data.aws_lb.main.dns_name}" # Placeholder
    zone_id                = data.aws_lb.main.zone_id                 # Would need actual secondary LB zone
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
resource "aws_sns_topic_subscription" "email_alerts" {
  count = var.domain_name != "" && var.enable_disaster_recovery ? 1 : 0

  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = "admin@${var.domain_name}" # Change to actual email
}

# Secondary region ECS cluster (placeholder for DR)
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
