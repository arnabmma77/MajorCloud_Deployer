# SSL/TLS Certificate Configuration using AWS Certificate Manager (ACM)

# Request SSL/TLS certificate for custom domain
resource "aws_acm_certificate" "main" {
  count = var.domain_name != "" ? 1 : 0

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-certificate"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Automatically validate certificate using DNS
resource "aws_route53_record" "cert_validation" {
  for_each = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main[0].zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "main" {
  count = var.domain_name != "" ? 1 : 0

  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "30m"
  }
}

# HTTPS Listener for ALB (port 443)
resource "aws_lb_listener" "https" {
  count = var.domain_name != "" ? 1 : 0

  load_balancer_arn = data.aws_lb.main.arn

  port            = "443"
  protocol        = "HTTPS"
  ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn = aws_acm_certificate_validation.main[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = data.aws_lb_target_group.app.arn
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-https-listener"
  })
}

# HTTP to HTTPS redirect rule
resource "aws_lb_listener_rule" "redirect_http_to_https" {
  count = var.domain_name != "" ? 1 : 0

  listener_arn = aws_lb_listener.app.arn
  priority     = 1

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-http-redirect"
  })
}

# Secondary Region Certificate (for disaster recovery)
resource "aws_acm_certificate" "secondary" {
  count = var.domain_name != "" && var.enable_disaster_recovery ? 1 : 0

  provider                  = aws.secondary
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = merge(local.common_tags, {
    Name   = "${local.name_prefix}-certificate-secondary"
    Region = "secondary"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Note: DNS validation records are the same for both regions
# The secondary certificate will use the same Route 53 validation records

# Certificate validation for secondary region
resource "aws_acm_certificate_validation" "secondary" {
  count = var.domain_name != "" && var.enable_disaster_recovery ? 1 : 0

  provider                = aws.secondary
  certificate_arn         = aws_acm_certificate.secondary[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "30m"
  }
}

# CloudWatch Alarm for certificate expiration
resource "aws_cloudwatch_metric_alarm" "certificate_expiry" {
  count = var.domain_name != "" ? 1 : 0

  alarm_name          = "${local.name_prefix}-certificate-expiry"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DaysToExpiry"
  namespace           = "AWS/CertificateManager"
  period              = "86400" # 1 day
  statistic           = "Minimum"
  threshold           = "30" # Alert if less than 30 days to expiry
  alarm_description   = "Alert when SSL certificate has less than 30 days until expiry"
  treat_missing_data  = "notBreaching"

  dimensions = {
    CertificateArn = aws_acm_certificate.main[0].arn
  }

  alarm_actions = var.enable_disaster_recovery ? [aws_sns_topic.alerts[0].arn] : []

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cert-expiry-alarm"
  })
}
