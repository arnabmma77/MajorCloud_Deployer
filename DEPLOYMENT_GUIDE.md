# Complete AWS Deployment Guide

This guide walks you through deploying the weather application to AWS from scratch.

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] AWS Account with billing enabled
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Docker installed and running
- [ ] Terraform 1.6+ installed
- [ ] GitHub account
- [ ] OpenWeather API key
- [ ] Domain name (optional, for Route 53)

## Step-by-Step Deployment

### Phase 1: Initial Setup (15 minutes)

#### 1.1 Create OpenWeather API Key

```bash
# Visit https://openweathermap.org/api
# Sign up for free account
# Navigate to API Keys section
# Copy your API key
export OPENWEATHER_API_KEY="your_api_key_here"
```

#### 1.2 Configure AWS CLI

```bash
# Configure AWS credentials
aws configure

# Verify access
aws sts get-caller-identity

# Set default region
export AWS_DEFAULT_REGION=us-east-1
```

#### 1.3 Clone Repository

```bash
git clone <your-repo-url>
cd weather-app
```

### Phase 2: Container Registry Setup (10 minutes)

#### 2.1 Create ECR Repository

```bash
# Create repository
aws ecr create-repository \
  --repository-name weather-app \
  --region $AWS_DEFAULT_REGION \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256

# Save repository URI
export ECR_URI=$(aws ecr describe-repositories \
  --repository-names weather-app \
  --query 'repositories[0].repositoryUri' \
  --output text)

echo "ECR Repository URI: $ECR_URI"
```

#### 2.2 Build and Push Initial Image

```bash
# Navigate to app directory
cd app

# Build Docker image
docker build -t weather-app:v1.0.0 .

# Login to ECR
aws ecr get-login-password --region $AWS_DEFAULT_REGION | \
  docker login --username AWS --password-stdin $ECR_URI

# Tag and push
docker tag weather-app:v1.0.0 $ECR_URI:v1.0.0
docker tag weather-app:v1.0.0 $ECR_URI:latest
docker push $ECR_URI:v1.0.0
docker push $ECR_URI:latest

echo "✅ Image pushed successfully"
cd ..
```

### Phase 3: Terraform Backend Setup (10 minutes)

#### 3.1 Create S3 Bucket for State

```bash
# Generate unique bucket name
BUCKET_SUFFIX=$(openssl rand -hex 4)
BUCKET_NAME="weather-app-tfstate-${BUCKET_SUFFIX}"

# Create bucket
aws s3 mb s3://${BUCKET_NAME} --region $AWS_DEFAULT_REGION

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Block public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Terraform state bucket: $BUCKET_NAME"
```

#### 3.2 Create DynamoDB Lock Table

```bash
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_DEFAULT_REGION

echo "✅ DynamoDB lock table created"
```

#### 3.3 Update Terraform Backend Configuration

```bash
cd terraform

# Create backend configuration
cat > backend-override.tf <<EOF
terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "weather-app/terraform.tfstate"
    region         = "${AWS_DEFAULT_REGION}"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
EOF

echo "✅ Backend configuration created"
```

### Phase 4: Infrastructure Deployment (20 minutes)

#### 4.1 Create Terraform Variables File

```bash
cat > terraform.tfvars <<EOF
# AWS Configuration
aws_primary_region   = "${AWS_DEFAULT_REGION}"
aws_secondary_region = "us-west-2"
environment          = "prod"
app_name            = "weather-app"

# Application Configuration
openweather_api_key = "${OPENWEATHER_API_KEY}"
domain_name         = ""  # Leave empty if no domain

# ECS Configuration
ecs_cluster_name  = "weather-app-cluster"
ecs_service_name  = "weather-app-service"
ecs_desired_count = 2
ecs_task_cpu      = 512
ecs_task_memory   = 1024

# Features
enable_disaster_recovery = true
enable_auto_scaling      = true

# Auto Scaling
auto_scaling_min_capacity = 2
auto_scaling_max_capacity = 10

# Monitoring
log_retention_in_days      = 14
health_check_grace_period  = 300
EOF

echo "✅ Terraform variables configured"
```

#### 4.2 Initialize Terraform

```bash
terraform init

# Verify initialization
terraform version
terraform providers
```

#### 4.3 Plan Infrastructure

```bash
# Run plan
terraform plan -out=tfplan

# Review the plan carefully
# Look for: ~40-50 resources to be created
```

#### 4.4 Apply Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# This will take 10-15 minutes
# Progress indicators will show resource creation

# After completion, save outputs
terraform output > ../deployment-outputs.txt

# Get application URL
export APP_URL=$(terraform output -raw app_url)
echo "Application URL: $APP_URL"
```

### Phase 5: Verification (10 minutes)

#### 5.1 Verify ECS Cluster

```bash
# Check cluster status
aws ecs describe-clusters \
  --clusters weather-app-cluster \
  --query 'clusters[0].status'

# Should return: ACTIVE

# List running tasks
aws ecs list-tasks \
  --cluster weather-app-cluster \
  --service-name weather-app-service

# Check service status
aws ecs describe-services \
  --cluster weather-app-cluster \
  --services weather-app-service \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'
```

#### 5.2 Test Application Endpoints

```bash
# Wait for ALB to be healthy (2-3 minutes)
sleep 180

# Test health endpoint
curl -v "$APP_URL/health"
# Expected: 200 OK with {"status":"healthy"}

# Test frontend
curl -I "$APP_URL/"
# Expected: 200 OK

# Test weather API
curl "$APP_URL/api/weather?city=London" | jq
# Expected: JSON with weather data

# Test forecast API
curl "$APP_URL/api/forecast?city=Paris" | jq
# Expected: JSON with 5-day forecast
```

#### 5.3 Check CloudWatch Logs

```bash
# Stream application logs
aws logs tail /ecs/weather-app-prod --follow

# Look for:
# - Container startup messages
# - Health check requests
# - API requests
```

#### 5.4 Verify Auto-Scaling

```bash
# Check auto-scaling target
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --resource-ids service/weather-app-cluster/weather-app-service

# Check scaling policies
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs \
  --resource-id service/weather-app-cluster/weather-app-service
```

### Phase 6: GitHub Actions Setup (15 minutes)

#### 6.1 Create IAM User for CI/CD

```bash
# Create IAM user for GitHub Actions
aws iam create-user --user-name github-actions-weather-app

# Attach necessary policies
aws iam attach-user-policy \
  --user-name github-actions-weather-app \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess

aws iam attach-user-policy \
  --user-name github-actions-weather-app \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

aws iam attach-user-policy \
  --user-name github-actions-weather-app \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Create access key
aws iam create-access-key --user-name github-actions-weather-app

# Save the AccessKeyId and SecretAccessKey from output
```

#### 6.2 Configure GitHub Secrets

```bash
# Using GitHub CLI (or do manually in GitHub UI)
gh secret set AWS_ACCESS_KEY_ID -b"your_access_key_id"
gh secret set AWS_SECRET_ACCESS_KEY -b"your_secret_access_key"
gh secret set OPENWEATHER_API_KEY -b"${OPENWEATHER_API_KEY}"
gh secret set DOMAIN_NAME -b""  # Optional

echo "✅ GitHub secrets configured"
```

#### 6.3 Test CI/CD Pipeline

```bash
# Make a small change
echo "# Test deployment" >> README.md

# Commit and push
git add .
git commit -m "test: Trigger CI/CD pipeline"
git push origin main

# Monitor workflow
gh run list --workflow=ci.yml
gh run watch

# After CI completes, CD will run automatically
gh run list --workflow=cd.yml
```

### Phase 7: Custom Domain Setup (Optional, 20 minutes)

#### 7.1 Create Route 53 Hosted Zone

```bash
# Create hosted zone for your domain
aws route53 create-hosted-zone \
  --name your-domain.com \
  --caller-reference $(date +%s)

# Save name servers
aws route53 list-hosted-zones-by-name \
  --dns-name your-domain.com \
  --query 'HostedZones[0].Id' \
  --output text

# Update your domain registrar with these name servers
```

#### 7.2 Request SSL Certificate

```bash
# Request certificate from ACM
aws acm request-certificate \
  --domain-name your-domain.com \
  --subject-alternative-names "*.your-domain.com" \
  --validation-method DNS \
  --region $AWS_DEFAULT_REGION

# Validate certificate (follow DNS validation instructions)
# This can take 5-30 minutes
```

#### 7.3 Update Terraform for Custom Domain

```bash
cd terraform

# Update terraform.tfvars
sed -i 's/domain_name = ""/domain_name = "your-domain.com"/' terraform.tfvars

# Apply changes
terraform plan -out=tfplan
terraform apply tfplan

# DNS propagation can take up to 48 hours
```

### Phase 8: Disaster Recovery Setup (30 minutes)

#### 8.1 Create Secondary Region Infrastructure

The Terraform configuration already includes secondary region setup. Verify it's enabled:

```bash
grep "enable_disaster_recovery = true" terraform.tfvars
```

#### 8.2 Push Image to Secondary Region

```bash
# Get secondary ECR URI
export ECR_SECONDARY_URI=$(terraform output -raw secondary_region_ecr_repository_url)

# Login to secondary region ECR
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin $ECR_SECONDARY_URI

# Tag and push
docker tag weather-app:v1.0.0 $ECR_SECONDARY_URI:v1.0.0
docker tag weather-app:v1.0.0 $ECR_SECONDARY_URI:latest
docker push $ECR_SECONDARY_URI:v1.0.0
docker push $ECR_SECONDARY_URI:latest

echo "✅ Image replicated to secondary region"
```

#### 8.3 Test Failover

```bash
# Simulate primary region failure
aws ecs update-service \
  --cluster weather-app-cluster \
  --service weather-app-service \
  --desired-count 0 \
  --region us-east-1

# Monitor health check (will fail in ~3 minutes)
watch -n 10 'aws route53 get-health-check-status \
  --health-check-id $(terraform output -raw route53_health_check_primary_id) \
  --query "HealthCheckObservations[0].StatusReport.Status"'

# Traffic will automatically route to secondary region
# Verify application is still accessible via domain

# Restore primary region
aws ecs update-service \
  --cluster weather-app-cluster \
  --service weather-app-service \
  --desired-count 2 \
  --region us-east-1

echo "✅ Failover tested successfully"
```

## Post-Deployment Checklist

- [ ] Application accessible via ALB DNS
- [ ] Health endpoint returning 200 OK
- [ ] Weather API returning data
- [ ] ECS tasks running and healthy
- [ ] Auto-scaling configured and working
- [ ] CloudWatch logs streaming
- [ ] GitHub Actions CI/CD working
- [ ] (Optional) Custom domain configured
- [ ] (Optional) SSL certificate issued
- [ ] (Optional) Secondary region active
- [ ] Cost alerts configured
- [ ] Backup strategy documented

## Monitoring and Maintenance

### Daily Checks

```bash
# Check application health
curl -s "$APP_URL/health" | jq

# Check ECS service status
aws ecs describe-services \
  --cluster weather-app-cluster \
  --services weather-app-service \
  --query 'services[0].{status:status,running:runningCount}'
```

### Weekly Checks

```bash
# Review CloudWatch logs for errors
aws logs filter-log-events \
  --log-group-name /ecs/weather-app-prod \
  --filter-pattern "ERROR" \
  --start-time $(date -d '7 days ago' +%s)000

# Check AWS costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost
```

### Monthly Tasks

- Review and optimize costs
- Update Docker base images
- Rotate access keys and secrets
- Test disaster recovery procedures
- Review security group rules
- Update dependencies

## Troubleshooting Common Issues

### Issue: Tasks Keep Restarting

```bash
# Check task failure reason
aws ecs describe-tasks \
  --cluster weather-app-cluster \
  --tasks $(aws ecs list-tasks --cluster weather-app-cluster --query 'taskArns[0]' --output text) \
  --query 'tasks[0].stopCode'

# Check logs
aws logs tail /ecs/weather-app-prod --follow

# Common causes:
# - Invalid OPENWEATHER_API_KEY
# - Insufficient memory/CPU
# - Application crashes
```

### Issue: High Costs

```bash
# Identify cost drivers
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Optimization options:
# - Use Fargate Spot
# - Reduce task count during low traffic
# - Enable S3 lifecycle policies
# - Review CloudWatch log retention
```

### Issue: SSL Certificate Not Validating

```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(aws acm list-certificates --query 'CertificateSummaryList[0].CertificateArn' --output text)

# Verify DNS validation records
aws route53 list-resource-record-sets \
  --hosted-zone-id $(terraform output -raw route53_zone_id) \
  --query "ResourceRecordSets[?Type=='CNAME']"
```

## Cleanup Instructions

To completely remove all resources:

```bash
# Warning: This will delete everything!

# Scale down ECS service first
aws ecs update-service \
  --cluster weather-app-cluster \
  --service weather-app-service \
  --desired-count 0

# Wait for tasks to stop
aws ecs wait services-stable \
  --cluster weather-app-cluster \
  --services weather-app-service

# Destroy infrastructure with Terraform
cd terraform
terraform destroy -auto-approve

# Delete ECR images
aws ecr batch-delete-image \
  --repository-name weather-app \
  --image-ids $(aws ecr list-images --repository-name weather-app --query 'imageIds[*]' --output json)

# Delete ECR repository
aws ecr delete-repository \
  --repository-name weather-app \
  --force

# Delete Terraform state bucket
aws s3 rb s3://${BUCKET_NAME} --force

# Delete DynamoDB lock table
aws dynamodb delete-table --table-name terraform-lock

echo "✅ All resources cleaned up"
```

## Next Steps

After successful deployment:

1. **Set Up Monitoring Dashboards**: Create CloudWatch dashboards for key metrics
2. **Configure Alerts**: Set up SNS notifications for critical events
3. **Implement Blue/Green Deployments**: Enhance CD workflow for zero-downtime deployments
4. **Add Performance Testing**: Implement load testing in CI/CD pipeline
5. **Enable AWS WAF**: Add web application firewall for security
6. **Implement Caching**: Add Redis/ElastiCache for API response caching
7. **Set Up Log Analytics**: Use CloudWatch Insights for log analysis

## Support

For issues or questions:
- Check logs: `aws logs tail /ecs/weather-app-prod --follow`
- Review Terraform state: `terraform show`
- Validate configuration: `terraform validate`
- Check AWS service health: https://health.aws.amazon.com/health/status

---

**Deployment Time Estimate**: 2-3 hours for complete setup
**Ongoing Maintenance**: ~2-4 hours per month
