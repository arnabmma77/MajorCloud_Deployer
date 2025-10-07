# AWS Architecture & Disaster Recovery Guide

Comprehensive documentation of the multi-region AWS architecture, disaster recovery strategy, and operational procedures.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [AWS Services Used](#aws-services-used)
- [Network Architecture](#network-architecture)
- [High Availability Design](#high-availability-design)
- [Disaster Recovery Strategy](#disaster-recovery-strategy)
- [Security Architecture](#security-architecture)
- [Cost Optimization](#cost-optimization)

## Architecture Overview

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet Users                            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │   Route 53     │ ◄── DNS + Health Checks
                    │   Failover     │ ◄── Latency-based Routing
                    └────┬──────┬────┘
                         │      │
         ┌───────────────┘      └──────────────┐
         │                                      │
    PRIMARY REGION                         SECONDARY REGION
    (us-east-1)                           (us-west-2)
         │                                      │
         ▼                                      ▼
┌─────────────────────┐              ┌─────────────────────┐
│  Application Load   │              │  Application Load   │
│     Balancer        │              │     Balancer        │
│  (Multi-AZ)         │              │  (Multi-AZ)         │
└──────────┬──────────┘              └──────────┬──────────┘
           │                                     │
     ┌─────┴─────┐                        ┌─────┴─────┐
     │           │                        │           │
     ▼           ▼                        ▼           ▼
┌─────────┐ ┌─────────┐            ┌─────────┐ ┌─────────┐
│  ECS    │ │  ECS    │            │  ECS    │ │  ECS    │
│ Fargate │ │ Fargate │            │ Fargate │ │ Fargate │
│  Task   │ │  Task   │            │  Task   │ │  Task   │
│   AZ-a  │ │   AZ-b  │            │   AZ-a  │ │   AZ-b  │
└────┬────┘ └────┬────┘            └────┬────┘ └────┬────┘
     │           │                       │           │
     └─────┬─────┘                       └─────┬─────┘
           │                                   │
           ▼                                   ▼
    ┌─────────────┐                    ┌─────────────┐
    │     ECR     │◄───replication────►│     ECR     │
    └─────────────┘                    └─────────────┘
           │                                   │
           └──────────────┬────────────────────┘
                          │
                          ▼
                 ┌────────────────┐
                 │  OpenWeather   │
                 │      API       │
                 └────────────────┘

Supporting Services (Both Regions):
├── CloudWatch (Logs, Metrics, Alarms)
├── Secrets Manager (API Keys)
├── S3 (Static Assets, Terraform State)
├── DynamoDB (Terraform Lock)
└── SNS (Notifications)
```

## AWS Services Used

### Compute Services

#### 1. ECS (Elastic Container Service)

**Purpose**: Container orchestration and management

**Configuration**:
- **Launch Type**: Fargate (serverless)
- **Cluster**: `weather-app-cluster`
- **Service**: `weather-app-service`
- **Task Definition**: 512 CPU (0.5 vCPU), 1024 MB memory
- **Desired Count**: 2 (can scale 2-10)
- **Container**: Weather app (Flask + Frontend)

**Benefits**:
- No EC2 instance management
- Automatic scaling based on metrics
- Built-in load balancing
- Rolling deployments with zero downtime
- Container Insights for monitoring

**Cost**: ~$30-40/month (2 tasks running 24/7)

#### 2. Fargate

**Purpose**: Serverless compute for containers

**Pricing Model**:
- **CPU**: $0.04048 per vCPU per hour
- **Memory**: $0.004445 per GB per hour
- **Example**: 0.5 vCPU + 1 GB = ~$22/month per task

**Advantages**:
- No EC2 management overhead
- Pay only for resources used
- Automatic patching and security updates
- Scales to zero (if needed)

### Networking Services

#### 1. Application Load Balancer (ALB)

**Purpose**: Distribute traffic across ECS tasks

**Configuration**:
- **Type**: Application Load Balancer (Layer 7)
- **Scheme**: Internet-facing
- **Listeners**: HTTP (port 80), HTTPS (port 443)
- **Target Type**: IP (for Fargate)
- **Health Check**: GET /health every 30s
- **Subnets**: 2 public subnets across 2 AZs

**Features**:
- Path-based routing
- Host-based routing
- WebSocket support
- Sticky sessions (if needed)
- Integration with WAF (optional)

**Cost**: ~$18-25/month

#### 2. VPC (Virtual Private Cloud)

**Configuration**:
- **CIDR Block**: 10.0.0.0/16
- **Public Subnets**: 10.0.1.0/24, 10.0.2.0/24
- **Availability Zones**: 2 AZs for high availability
- **Internet Gateway**: For public internet access
- **NAT Gateway**: For private subnet egress (optional)

**Security Groups**:

1. **ALB Security Group**:
   - Inbound: 80/tcp from 0.0.0.0/0
   - Inbound: 443/tcp from 0.0.0.0/0
   - Outbound: All to ECS tasks

2. **ECS Tasks Security Group**:
   - Inbound: 8080/tcp from ALB
   - Outbound: All (for API calls)

#### 3. Route 53

**Purpose**: DNS management and traffic routing

**Configuration**:
- **Hosted Zone**: For custom domain
- **Record Types**: A records with alias to ALB
- **Routing Policy**: Failover (PRIMARY/SECONDARY)
- **Health Checks**: Monitor ALB endpoints
- **TTL**: 60 seconds for fast failover

**Failover Configuration**:
```
Primary Record:
  Type: A
  Set Identifier: primary-us-east-1
  Routing: Failover PRIMARY
  Health Check: /health endpoint
  Target: ALB in us-east-1

Secondary Record:
  Type: A
  Set Identifier: secondary-us-west-2
  Routing: Failover SECONDARY
  Health Check: /health endpoint
  Target: ALB in us-west-2
```

### Storage Services

#### 1. ECR (Elastic Container Registry)

**Purpose**: Docker image storage

**Configuration**:
- **Repositories**: weather-app (primary), weather-app (secondary)
- **Image Scanning**: Enabled on push
- **Encryption**: AES256
- **Lifecycle Policy**: Keep last 10 prod images, 5 dev images

**Features**:
- Automated vulnerability scanning
- Image signing
- Cross-region replication
- Integration with ECS

**Cost**: $0.10 per GB-month (~$1/month)

#### 2. S3 (Simple Storage Service)

**Buckets**:

1. **Terraform State Bucket**:
   - Purpose: Store infrastructure state
   - Versioning: Enabled
   - Encryption: AES256
   - Public Access: Blocked
   - Lifecycle: Never delete

2. **Static Assets Bucket**:
   - Purpose: Store static files, backups
   - Versioning: Enabled
   - Lifecycle: Transition to IA after 30 days
   - CloudFront Distribution: For CDN

**Cost**: $0.023 per GB-month (~$0.25/month)

#### 3. DynamoDB

**Purpose**: Terraform state locking

**Configuration**:
- **Table Name**: terraform-lock
- **Primary Key**: LockID (String)
- **Billing Mode**: PAY_PER_REQUEST
- **Encryption**: Enabled

**Cost**: Minimal (~$0.05/month)

### Monitoring Services

#### 1. CloudWatch

**Components**:

1. **Logs**:
   - Log Group: `/ecs/weather-app-prod`
   - Retention: 14 days
   - Streams: One per ECS task

2. **Metrics**:
   - Container Insights enabled
   - Custom metrics from application
   - ALB metrics (requests, latency, errors)

3. **Alarms**:
   - High CPU utilization (>70%)
   - High memory utilization (>80%)
   - Health check failures
   - 5xx errors from ALB

**Cost**: ~$2.50/month for 5 GB logs

#### 2. SNS (Simple Notification Service)

**Purpose**: Alert notifications

**Topics**:
- `weather-app-health-alerts`: Health check failures
- `weather-app-scaling-events`: Auto-scaling notifications
- `weather-app-deployments`: Deployment status

**Subscriptions**: Email, SMS, Lambda

**Cost**: Minimal (~$0.50/month)

### Security Services

#### 1. Secrets Manager

**Purpose**: Secure API key storage

**Secrets**:
- `weather-app-openweather-api-key`: OpenWeather API key
- Automatic rotation: Not configured (manual rotation recommended)

**Cost**: $0.40 per secret per month

#### 2. IAM (Identity and Access Management)

**Roles**:

1. **ECS Task Execution Role**:
   - Purpose: Pull images, write logs
   - Policies: AmazonECSTaskExecutionRolePolicy

2. **ECS Task Role**:
   - Purpose: Application permissions
   - Policies: S3 access, Secrets Manager access

3. **GitHub Actions Role**:
   - Purpose: CI/CD deployments
   - Policies: ECR push, ECS update, Terraform apply

### Optional Services

#### 1. ACM (AWS Certificate Manager)

**Purpose**: SSL/TLS certificates for HTTPS

**Configuration**:
- Certificate Type: Public
- Domain Names: your-domain.com, *.your-domain.com
- Validation: DNS (automatic)
- Renewal: Automatic

**Cost**: Free for public certificates

#### 2. CloudFront

**Purpose**: CDN for static assets

**Configuration**:
- Origin: S3 bucket
- Price Class: Use Only U.S., Canada, and Europe
- Compression: Enabled
- HTTPS: Redirect HTTP to HTTPS

**Cost**: ~$0.085 per GB transfer

#### 3. WAF (Web Application Firewall)

**Purpose**: Protect against web attacks

**Rules** (Recommended):
- Rate limiting: 2000 requests per 5 minutes
- SQL injection protection
- XSS protection
- Geographic blocking (if needed)

**Cost**: ~$5/month + $1 per million requests

## High Availability Design

### Multi-AZ Deployment

**Configuration**:
- ALB spans 2 availability zones
- ECS tasks distributed across AZs
- Minimum 1 task per AZ
- Automatic task replacement on failure

**Availability Target**: 99.95% (~22 minutes downtime/month)

### Auto-Scaling

**Scaling Policies**:

1. **CPU-Based Scaling**:
   ```hcl
   Target: 70% CPU utilization
   Min Tasks: 2
   Max Tasks: 10
   Scale Out: Add 1 task if CPU > 70% for 2 minutes
   Scale In: Remove 1 task if CPU < 50% for 5 minutes
   ```

2. **Memory-Based Scaling**:
   ```hcl
   Target: 80% memory utilization
   Min Tasks: 2
   Max Tasks: 10
   ```

3. **Request-Based Scaling** (Optional):
   ```hcl
   Target: 1000 requests per task per minute
   ```

### Health Checks

**ALB Target Group Health Check**:
- **Path**: /health
- **Interval**: 30 seconds
- **Timeout**: 5 seconds
- **Healthy Threshold**: 2 consecutive successes
- **Unhealthy Threshold**: 2 consecutive failures

**Route 53 Health Check**:
- **Type**: HTTP
- **Path**: /health
- **Interval**: 30 seconds
- **Failure Threshold**: 3 failures
- **CloudWatch Alarm**: On health check failure

## Disaster Recovery Strategy

### RTO and RPO Targets

**Recovery Time Objective (RTO)**: 5 minutes
- Time to detect failure: 3 minutes (health checks)
- DNS propagation: 1-2 minutes
- Application startup: Immediate (already running)

**Recovery Point Objective (RPO)**: Near-zero
- Stateless application (no data loss)
- Container images replicated to both regions
- Infrastructure code in version control

### DR Architecture

#### Active-Passive Configuration

**Primary Region (us-east-1)**:
- Handles 100% of traffic
- 2-10 ECS tasks running
- Route 53 PRIMARY record

**Secondary Region (us-west-2)**:
- Standby mode
- 2 ECS tasks running (warm standby)
- Route 53 SECONDARY record
- Activated only on primary failure

#### Failover Process

**Automatic Failover**:
1. Primary region health check fails (3 consecutive failures = 90 seconds)
2. Route 53 marks primary as unhealthy (30 seconds)
3. Route 53 starts routing to secondary (immediate)
4. DNS caches update (60-120 seconds)
5. CloudWatch alarm triggered
6. SNS notification sent to operators

**Total Failover Time**: 3-5 minutes

**Manual Failover**:
```bash
# Update Route 53 record sets to force failover
aws route53 change-resource-record-sets \
  --hosted-zone-id ZONE_ID \
  --change-batch file://failover-change.json
```

#### Failback Process

**After Primary Region Recovered**:
1. Verify primary region health
2. Scale up primary region ECS service
3. Wait for tasks to be healthy (2-3 minutes)
4. Route 53 automatically fails back when primary health check passes
5. Monitor for any issues
6. Document incident in runbook

### Data Consistency

**Stateless Application**:
- No database (stateless design)
- No user sessions (stateless API)
- No data synchronization required

**If Database Were Added**:
- Use RDS Multi-AZ in each region
- Cross-region read replicas
- Or use DynamoDB Global Tables

### DR Testing

**Monthly DR Drill**:
```bash
# 1. Document baseline
curl -s "https://your-domain.com/health"

# 2. Simulate primary failure
aws ecs update-service \
  --cluster weather-app-cluster \
  --service weather-app-service \
  --desired-count 0 \
  --region us-east-1

# 3. Monitor failover (should take 3-5 minutes)
watch -n 10 'dig +short your-domain.com'

# 4. Verify secondary region serving traffic
curl -s "https://your-domain.com/health"

# 5. Restore primary region
aws ecs update-service \
  --cluster weather-app-cluster \
  --service weather-app-service \
  --desired-count 2 \
  --region us-east-1

# 6. Verify automatic failback
watch -n 10 'dig +short your-domain.com'

# 7. Document results
```

**Quarterly DR Exercises**:
- Full regional failover test
- Database recovery test (if applicable)
- Backup restoration test
- Documentation review and update

## Security Architecture

### Network Security

**Defense in Depth**:
1. **Perimeter**: WAF (optional) blocks malicious requests
2. **Load Balancer**: ALB with HTTPS termination
3. **Security Groups**: Restrict ECS task access
4. **Container**: Non-root user, read-only filesystem
5. **Application**: Input validation, rate limiting

### IAM Best Practices

**Principle of Least Privilege**:
- Each role has minimal permissions
- No wildcard (*) permissions
- Time-limited access tokens
- MFA for console access

**Roles Summary**:
```
ECS Task Execution Role:
  - ecr:GetAuthorizationToken
  - ecr:BatchCheckLayerAvailability
  - ecr:GetDownloadUrlForLayer
  - ecr:BatchGetImage
  - logs:CreateLogStream
  - logs:PutLogEvents

ECS Task Role:
  - s3:GetObject (specific bucket)
  - secretsmanager:GetSecretValue (specific secret)

GitHub Actions:
  - ecr:*
  - ecs:UpdateService
  - ecs:DescribeServices
  - Terraform state bucket access
```

### Secrets Management

**API Keys**:
- Stored in AWS Secrets Manager
- Encrypted at rest (KMS)
- Accessed via IAM roles
- Never logged or exposed

**Rotation Policy**:
- Rotate OpenWeather API key: Quarterly
- Rotate AWS access keys: Monthly
- Rotate application secrets: As needed

### Compliance

**Data Protection**:
- Encryption in transit: TLS 1.2+
- Encryption at rest: All S3, EBS, RDS
- No PII stored (stateless application)

**Logging**:
- All API requests logged to CloudWatch
- Access logs for ALB
- VPC Flow Logs (optional)
- CloudTrail for AWS API calls

## Cost Optimization

### Monthly Cost Breakdown

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| ECS Fargate | 2 tasks × 0.5 vCPU, 1 GB | $30-40 |
| Application Load Balancer | 1 ALB | $18-25 |
| Route 53 | 1 hosted zone + 2 health checks | $3-5 |
| ECR | <1 GB storage | $0.10 |
| S3 | <10 GB storage | $0.25 |
| CloudWatch Logs | 5 GB/month | $2.50 |
| Secrets Manager | 1 secret | $0.40 |
| Data Transfer | 100 GB/month | $9 |
| **Subtotal** | | **$63-82/month** |
| Secondary Region (DR) | Same as primary | $63-82/month |
| **Total (Both Regions)** | | **$126-164/month** |

### Cost Optimization Strategies

#### 1. Use Fargate Spot (70% savings)

```hcl
capacity_providers = ["FARGATE_SPOT", "FARGATE"]

default_capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight           = 70
  base             = 0
}

default_capacity_provider_strategy {
  capacity_provider = "FARGATE"
  weight           = 30
  base             = 1
}
```

**Savings**: ~$21/month per region

#### 2. Scale Down During Off-Hours

```bash
# Schedule ECS service scaling
# Morning (8 AM): Scale to 2 tasks
# Evening (10 PM): Scale to 1 task

# Use EventBridge + Lambda for automation
```

**Savings**: ~$15/month

#### 3. Use S3 Lifecycle Policies

```hcl
lifecycle_rule {
  enabled = true
  
  transition {
    days          = 30
    storage_class = "STANDARD_IA"
  }
  
  transition {
    days          = 90
    storage_class = "GLACIER"
  }
}
```

**Savings**: ~60% on storage costs

#### 4. Reduce CloudWatch Log Retention

```hcl
log_retention_in_days = 7  # Instead of 14
```

**Savings**: ~$1.25/month

#### 5. Use Reserved Capacity (for stable workloads)

- ECS Fargate: Up to 50% savings with Compute Savings Plans
- Requires 1 or 3 year commitment

### Secondary Region Cost Optimization

**Option 1: Cold Standby** (Cost: $10-15/month)
- No running ECS tasks
- Infrastructure deployed but scaled to zero
- Spin up only during DR event
- RTO: 10-15 minutes

**Option 2: Warm Standby** (Cost: $63-82/month)
- 2 tasks running at minimum
- Ready to handle traffic immediately
- RTO: 3-5 minutes

**Option 3: Active-Active** (Cost: $126-164/month)
- Both regions handle production traffic
- Load balanced via Route 53 latency routing
- RTO: Near-zero

**Recommendation**: Warm Standby for production, Cold Standby for dev/staging

## Operational Procedures

### Daily Operations

**Morning Health Check**:
```bash
# Check application status
curl -s "$APP_URL/health" | jq

# Check ECS service
aws ecs describe-services \
  --cluster weather-app-cluster \
  --services weather-app-service \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'

# Review CloudWatch alarms
aws cloudwatch describe-alarms \
  --state-value ALARM \
  --query 'MetricAlarms[*].AlarmName'
```

### Weekly Maintenance

**Security Updates**:
- Review ECR image scan results
- Update base Docker images
- Apply Terraform updates

**Performance Review**:
- Analyze CloudWatch metrics
- Review auto-scaling events
- Check cost anomalies

### Monthly Tasks

- DR drill and documentation
- Cost optimization review
- Security audit
- Backup verification
- Update runbooks

### Incident Response

**Severity Levels**:

1. **Critical (P1)**: Service down
   - Response Time: Immediate
   - Notification: PagerDuty + Phone
   - Action: Activate incident response team

2. **High (P2)**: Degraded performance
   - Response Time: 15 minutes
   - Notification: PagerDuty + Slack
   - Action: Investigate and mitigate

3. **Medium (P3)**: Non-critical issue
   - Response Time: 2 hours
   - Notification: Slack
   - Action: Schedule fix

4. **Low (P4)**: Minor issue
   - Response Time: Next business day
   - Notification: Email
   - Action: Add to backlog

### Runbook Examples

**Runbook: Primary Region Failure**
```
1. Verify incident:
   - Check CloudWatch alarms
   - Confirm health check failures
   - Verify Route 53 failover activated

2. Validate secondary region:
   - Check ECS service status in us-west-2
   - Test application endpoints
   - Monitor CloudWatch logs

3. Communicate:
   - Update status page
   - Notify stakeholders
   - Start incident timeline

4. Root cause analysis:
   - Review primary region logs
   - Check AWS service health
   - Document findings

5. Resolution:
   - Fix primary region issues
   - Test primary region health
   - Coordinate failback
   - Post-mortem review
```

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Owner**: DevOps Team  
**Review Schedule**: Quarterly
