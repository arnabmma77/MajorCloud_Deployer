# Automated Multi-Region Cloud Deployment with CI/CD, IaC & Disaster Recovery

A comprehensive educational reference project demonstrating modern cloud deployment practices using Docker containerization, Terraform Infrastructure as Code (IaC), GitHub Actions CI/CD, and AWS multi-region disaster recovery architecture.

> **Note:** This is an educational reference implementation. The code is production-ready and can be deployed in any Docker-supported environment with AWS access.

## 🏗️ Architecture Overview

This project showcases a full-stack weather application with:

- **Frontend**: Modern weather dashboard with responsive design
- **Backend**: Python Flask API proxy for OpenWeatherMap integration
- **Infrastructure**: AWS ECS Fargate, Application Load Balancer, Route 53
- **CI/CD**: Automated testing, building, and deployment with GitHub Actions
- **Monitoring**: Health checks, CloudWatch logging, and alerting
- **Disaster Recovery**: Multi-region failover with Route 53 health checks

## 📁 Project Structure

```
project/
├── app/
│   ├── backend/
│   │   ├── app.py                 # Flask API server
│   │   └── requirements.txt       # Python dependencies
│   ├── frontend/
│   │   ├── index.html            # Weather dashboard UI
│   │   ├── script.js             # Frontend logic
│   │   └── style.css             # Responsive styles
│   └── Dockerfile                # Multi-stage Docker build
├── terraform/
│   ├── backend.tf                # Terraform remote state config
│   ├── main.tf                   # VPC, networking, ALB
│   ├── ecr.tf                    # Container registry
│   ├── ecs.tf                    # ECS cluster, tasks, auto-scaling
│   ├── s3.tf                     # S3 buckets, CloudFront CDN
│   ├── route53.tf                # DNS, health checks, failover
│   ├── variables.tf              # Terraform variables
│   └── outputs.tf                # Output values
├── .github/workflows/
│   ├── ci.yml                    # Continuous Integration
│   └── cd.yml                    # Continuous Deployment
├── .env.example                  # Environment variables template
└── README.md                     # This file
```

## 🚀 Quick Start (Local Development)

### Prerequisites

- Docker and Docker Compose
- OpenWeather API key ([Get one free](https://openweathermap.org/api))
- AWS account (for cloud deployment)
- Terraform 1.6+ (for infrastructure)
- GitHub account (for CI/CD)

### 1. Clone and Configure

```bash
# Copy environment template
cp .env.example .env

# Edit .env and add your OpenWeather API key
nano .env
```

### 2. Run Locally with Docker

```bash
# Navigate to app directory
cd app

# Build the Docker image
docker build -t weather-app:latest .

# Run the container
docker run -d \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key_here \
  --name weather-app \
  weather-app:latest

# View logs
docker logs -f weather-app

# Access the app
open http://localhost:8080
```

### 3. Test the Application

```bash
# Health check
curl http://localhost:8080/health

# Weather API
curl "http://localhost:8080/api/weather?city=London"

# Forecast API
curl "http://localhost:8080/api/forecast?city=Paris"
```

### 4. Stop and Clean Up

```bash
docker stop weather-app
docker rm weather-app
```

## ☁️ AWS Cloud Deployment

### Part 1: ECR (Elastic Container Registry)

#### Create ECR Repository

```bash
# Set your AWS region
export AWS_DEFAULT_REGION=us-east-1

# Create ECR repository
aws ecr create-repository \
  --repository-name weather-app \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256

# Get repository URI
export ECR_REPO_URI=$(aws ecr describe-repositories \
  --repository-names weather-app \
  --query 'repositories[0].repositoryUri' \
  --output text)

echo "ECR Repository: $ECR_REPO_URI"
```

#### Push Docker Image to ECR

```bash
# Login to ECR
aws ecr get-login-password --region $AWS_DEFAULT_REGION | \
  docker login --username AWS --password-stdin $ECR_REPO_URI

# Build and tag image
cd app
docker build -t weather-app:latest .
docker tag weather-app:latest $ECR_REPO_URI:latest
docker tag weather-app:latest $ECR_REPO_URI:v1.0.0

# Push to ECR
docker push $ECR_REPO_URI:latest
docker push $ECR_REPO_URI:v1.0.0

echo "✅ Image pushed to ECR"
```

### Part 2: Terraform Infrastructure Setup

#### Initialize Terraform Backend

```bash
cd terraform

# Create S3 bucket for Terraform state
BUCKET_NAME="weather-app-terraform-state-$(openssl rand -hex 4)"
aws s3 mb s3://$BUCKET_NAME --region $AWS_DEFAULT_REGION

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

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_DEFAULT_REGION

echo "Terraform backend created: $BUCKET_NAME"
```

#### Configure Backend in Terraform

Edit `terraform/backend.tf` and update the bucket name:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-bucket-name-here"  # Replace with $BUCKET_NAME
    key            = "weather-app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
```

#### Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
aws_primary_region   = "us-east-1"
aws_secondary_region = "us-west-2"
environment          = "prod"
openweather_api_key  = "your_api_key_here"
domain_name          = ""  # Optional: your domain
enable_disaster_recovery = true
enable_auto_scaling      = true
EOF

# Plan deployment
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Get outputs
terraform output

# Save important outputs
export ALB_DNS=$(terraform output -raw alb_dns_name)
export APP_URL=$(terraform output -raw app_url)
echo "Application URL: $APP_URL"
```

### Part 3: ECS (Elastic Container Service) Deployment

The Terraform configuration automatically creates:

1. **ECS Cluster**: `weather-app-cluster` on Fargate
2. **Task Definition**: Container specs with 512 CPU, 1024 MB memory
3. **ECS Service**: Runs 2 tasks with auto-scaling (2-10 tasks)
4. **Application Load Balancer**: Distributes traffic across tasks
5. **Target Group**: Health checks on `/health` endpoint
6. **Security Groups**: Controlled network access

#### Verify ECS Deployment

```bash
# Check cluster status
aws ecs describe-clusters --clusters weather-app-cluster

# Check service status
aws ecs describe-services \
  --cluster weather-app-cluster \
  --services weather-app-service

# List running tasks
aws ecs list-tasks \
  --cluster weather-app-cluster \
  --service-name weather-app-service

# Check task logs
aws logs tail /ecs/weather-app-prod --follow
```

#### Update ECS Service (Manual)

```bash
# Build and push new image
docker build -t weather-app:v1.1.0 .
docker tag weather-app:v1.1.0 $ECR_REPO_URI:v1.1.0
docker push $ECR_REPO_URI:v1.1.0

# Update service to use new image
aws ecs update-service \
  --cluster weather-app-cluster \
  --service weather-app-service \
  --force-new-deployment

# Wait for deployment to complete
aws ecs wait services-stable \
  --cluster weather-app-cluster \
  --services weather-app-service
```

### Part 4: Route 53 Failover Configuration

#### Prerequisites

- A registered domain name
- Route 53 hosted zone for your domain

#### Configure DNS Failover

The Terraform configuration includes:

1. **Primary Health Check**: Monitors ALB in `us-east-1`
2. **Secondary Health Check**: Monitors ALB in `us-west-2` (DR region)
3. **Failover Records**: PRIMARY and SECONDARY routing policies
4. **CloudWatch Alarms**: Alert on health check failures
5. **SNS Notifications**: Email alerts for failover events

#### Set Up with Your Domain

```bash
# Update terraform.tfvars
cat >> terraform.tfvars <<EOF
domain_name = "your-domain.com"
EOF

# Apply Terraform changes
terraform plan -out=tfplan
terraform apply tfplan

# Verify Route 53 records
aws route53 list-resource-record-sets \
  --hosted-zone-id $(terraform output -raw route53_zone_id)
```

#### Test Failover

```bash
# Simulate primary region failure (scale down to 0)
aws ecs update-service \
  --cluster weather-app-cluster \
  --service weather-app-service \
  --desired-count 0 \
  --region us-east-1

# Wait for health check to fail (3-5 minutes)
# Traffic will automatically route to secondary region

# Restore primary region
aws ecs update-service \
  --cluster weather-app-cluster \
  --service weather-app-service \
  --desired-count 2 \
  --region us-east-1
```

### Part 5: Monitoring and Auto-Scaling

#### CloudWatch Dashboards

The infrastructure includes:

- **Container Insights**: CPU, memory, network metrics
- **Application Logs**: Centralized logging in CloudWatch Logs
- **Health Check Status**: Route 53 health check metrics
- **ALB Metrics**: Request count, latency, error rates

#### View Logs

```bash
# Stream application logs
aws logs tail /ecs/weather-app-prod --follow

# Filter error logs
aws logs filter-log-events \
  --log-group-name /ecs/weather-app-prod \
  --filter-pattern "ERROR"

# Get health check logs
aws logs tail /aws/route53/health-checks --follow
```

#### Auto-Scaling Configuration

Auto-scaling policies are pre-configured:

- **CPU Scaling**: Target 70% CPU utilization
- **Memory Scaling**: Target 80% memory utilization
- **Min Capacity**: 2 tasks
- **Max Capacity**: 10 tasks

#### Test Auto-Scaling

```bash
# Generate load to trigger scaling
for i in {1..1000}; do
  curl -s "$APP_URL/api/weather?city=London" > /dev/null &
done

# Watch scaling activity
aws ecs describe-services \
  --cluster weather-app-cluster \
  --services weather-app-service \
  --query 'services[0].{desired:desiredCount,running:runningCount}'

# View scaling events
aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs \
  --resource-id service/weather-app-cluster/weather-app-service
```

## 🔄 CI/CD with GitHub Actions

### Setup GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

```
AWS_ACCESS_KEY_ID          # Your AWS access key
AWS_SECRET_ACCESS_KEY      # Your AWS secret key
OPENWEATHER_API_KEY        # OpenWeather API key
DOMAIN_NAME                # (Optional) Your domain
```

### CI Workflow (Continuous Integration)

Triggered on: Push to `main` or `develop`, Pull Requests

**Pipeline Steps:**

1. **Lint and Test**: Python linting with flake8, pytest unit tests
2. **Security Scan**: Bandit (code), Trivy (container), Checkov (Terraform)
3. **Build Docker Image**: Multi-stage build with caching
4. **Test Container**: Smoke tests on running container
5. **Push to ECR**: Tagged with commit SHA and `latest`
6. **Terraform Validate**: Syntax and configuration validation

```yaml
# Workflow runs automatically on push
git add .
git commit -m "Update application code"
git push origin main

# CI pipeline will run automatically
```

### CD Workflow (Continuous Deployment)

Triggered on: Successful CI completion (main branch only)

**Deployment Steps:**

1. **Configure AWS Credentials**: Authenticate with AWS
2. **Setup Terraform**: Initialize backend and providers
3. **Create/Update Infrastructure**: Apply Terraform changes
4. **Update ECS Service**: Deploy new container image
5. **Wait for Stability**: Monitor deployment status
6. **Health Checks**: Verify application is responding
7. **Smoke Tests**: Run integration tests
8. **Secondary Region**: Update DR region (if enabled)

```bash
# Manual deployment trigger
gh workflow run cd.yml \
  --ref main \
  -f environment=prod \
  -f force_deploy=false
```

### Rollback on Failure

The CD workflow includes automatic rollback:

```yaml
rollback:
  name: Rollback on Failure
  runs-on: ubuntu-latest
  needs: deploy
  if: failure()
  
  steps:
    - name: Rollback to previous version
      # Reverts to previous stable image
```

### Environment-Specific Deployments

```bash
# Deploy to staging
gh workflow run cd.yml -f environment=staging

# Deploy to production
gh workflow run cd.yml -f environment=prod

# Force deploy (skip CI check)
gh workflow run cd.yml -f environment=prod -f force_deploy=true
```

## 🔐 Security Best Practices

### Secrets Management

- ✅ API keys stored in AWS Secrets Manager
- ✅ GitHub Secrets for CI/CD credentials
- ✅ IAM roles with least-privilege access
- ✅ Encrypted S3 buckets and ECR repositories
- ✅ VPC security groups restrict network access

### Container Security

```bash
# Scan Docker image for vulnerabilities
trivy image weather-app:latest

# Run security audit on code
bandit -r app/backend/

# Terraform security scan
checkov -d terraform/
```

### Network Security

- ALB accepts only HTTP/HTTPS traffic (ports 80/443)
- ECS tasks only accept traffic from ALB
- No direct internet access to containers
- CloudWatch logs encrypted at rest

## 🧪 Testing

### Unit Tests

```bash
cd app/backend

# Install test dependencies
pip install pytest pytest-cov

# Run tests with coverage
pytest tests/ -v --cov=app --cov-report=html

# View coverage report
open htmlcov/index.html
```

### Integration Tests

```bash
# Start application
docker-compose up -d

# Run integration tests
pytest tests/integration/ -v

# Stop application
docker-compose down
```

### Load Testing

```bash
# Install Apache Bench
apt-get install apache2-utils

# Run load test (1000 requests, 10 concurrent)
ab -n 1000 -c 10 "$APP_URL/api/weather?city=London"

# View results
# Look for: Requests per second, Time per request, Failed requests
```

## 📊 Cost Estimation

### AWS Resources (Approximate Monthly Costs)

| Service | Configuration | Estimated Cost |
|---------|--------------|----------------|
| ECS Fargate | 2 tasks × 0.5 vCPU, 1 GB | $30-40 |
| Application Load Balancer | 1 ALB | $18-25 |
| ECR Storage | <1 GB images | $0.10 |
| CloudWatch Logs | 5 GB/month | $2.50 |
| Route 53 | 1 hosted zone + health checks | $3-5 |
| S3 Storage | <10 GB | $0.23 |
| Data Transfer | 100 GB/month | $9 |
| **Total** | | **~$63-82/month** |

**Cost Optimization Tips:**

- Use Fargate Spot for non-production environments (70% savings)
- Enable S3 lifecycle policies to archive old logs
- Use CloudFront CDN to reduce ALB data transfer costs
- Implement auto-scaling to scale down during low traffic

## 🆘 Troubleshooting

### Common Issues

#### 1. Container Won't Start

```bash
# Check ECS task logs
aws ecs describe-tasks \
  --cluster weather-app-cluster \
  --tasks $(aws ecs list-tasks --cluster weather-app-cluster --query 'taskArns[0]' --output text)

# View CloudWatch logs
aws logs tail /ecs/weather-app-prod --follow
```

#### 2. Health Check Failing

```bash
# Test health endpoint directly
curl -v http://$ALB_DNS/health

# Check security groups
aws ec2 describe-security-groups --group-ids $SG_ID

# Verify target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
```

#### 3. Terraform State Locked

```bash
# View lock info
aws dynamodb get-item \
  --table-name terraform-lock \
  --key '{"LockID":{"S":"weather-app/terraform.tfstate"}}'

# Force unlock (use carefully!)
terraform force-unlock <LOCK_ID>
```

#### 4. CI/CD Pipeline Failing

```bash
# Check GitHub Actions logs
gh run list --workflow=ci.yml
gh run view <RUN_ID> --log

# Validate Terraform locally
cd terraform
terraform validate
terraform fmt -check
```

## 🎯 Disaster Recovery Testing

### DR Drill Procedure

1. **Preparation**
   ```bash
   # Document baseline metrics
   curl -s "$APP_URL/health" | jq
   
   # Verify secondary region is ready
   aws ecs describe-clusters --clusters weather-app-cluster-secondary --region us-west-2
   ```

2. **Simulate Primary Failure**
   ```bash
   # Stop primary region tasks
   aws ecs update-service \
     --cluster weather-app-cluster \
     --service weather-app-service \
     --desired-count 0 \
     --region us-east-1
   ```

3. **Monitor Failover**
   ```bash
   # Watch health check status (should fail in 3-5 minutes)
   watch -n 10 'aws route53 get-health-check-status --health-check-id $(terraform output -raw route53_health_check_primary_id)'
   
   # Traffic should route to secondary region
   # DNS propagation may take 60-300 seconds
   ```

4. **Validate Secondary Region**
   ```bash
   # Test application from secondary region
   dig your-domain.com  # Should show secondary region IP
   curl -s "https://your-domain.com/health"
   ```

5. **Restore Primary Region**
   ```bash
   # Scale up primary region
   aws ecs update-service \
     --cluster weather-app-cluster \
     --service weather-app-service \
     --desired-count 2 \
     --region us-east-1
   
   # Verify failback (should happen in 3-5 minutes)
   ```

6. **Document Results**
   - Failover detection time
   - DNS propagation time
   - Total downtime experienced
   - Any issues encountered

## 📚 Additional Resources

### Documentation

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [OpenWeather API Documentation](https://openweathermap.org/api)

### Architecture Diagrams

```
┌─────────────────────────────────────────────────────────────┐
│                         User Request                         │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │   Route 53     │ (DNS + Health Checks)
                    │   Failover     │
                    └────┬──────┬────┘
                         │      │
         ┌───────────────┘      └──────────────┐
         │ Primary Region (us-east-1)          │ Secondary Region (us-west-2)
         ▼                                      ▼
┌─────────────────┐                    ┌─────────────────┐
│ Application     │                    │ Application     │
│ Load Balancer   │                    │ Load Balancer   │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         ▼                                      ▼
┌─────────────────┐                    ┌─────────────────┐
│   ECS Fargate   │                    │   ECS Fargate   │
│   (2-10 tasks)  │                    │   (2-10 tasks)  │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         ▼                                      ▼
┌─────────────────┐                    ┌─────────────────┐
│ Container       │                    │ Container       │
│ (Flask + React) │                    │ (Flask + React) │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         └──────────────┬───────────────────────┘
                        ▼
                ┌───────────────┐
                │  OpenWeather  │
                │     API       │
                └───────────────┘
```

## 🤝 Contributing

This is an educational reference project. Feel free to:

- Fork and modify for your needs
- Submit issues for bugs or improvements
- Create pull requests with enhancements
- Share your deployment experiences

## 📄 License

MIT License - Feel free to use this project for learning and production deployments.

## ⭐ Key Takeaways

This project demonstrates:

1. ✅ **Containerization**: Docker best practices for Python Flask applications
2. ✅ **Infrastructure as Code**: Terraform modules for reproducible AWS infrastructure
3. ✅ **CI/CD Automation**: GitHub Actions for automated testing and deployment
4. ✅ **High Availability**: Multi-AZ deployment with Application Load Balancer
5. ✅ **Disaster Recovery**: Multi-region failover with Route 53 health checks
6. ✅ **Auto-Scaling**: Dynamic scaling based on CPU and memory metrics
7. ✅ **Security**: IAM roles, security groups, encrypted storage
8. ✅ **Monitoring**: CloudWatch logs, metrics, and alarms
9. ✅ **Cost Optimization**: Fargate Spot, S3 lifecycle policies

---

**Built with ❤️ for learning cloud deployment best practices**

For questions or issues, please create a GitHub issue or reach out to the maintainers.
