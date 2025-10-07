# Deployment Checklist

Use this checklist to track your progress when deploying the weather application to AWS.

## Pre-Deployment

### Prerequisites
- [ ] AWS account created and billing enabled
- [ ] AWS CLI installed (`aws --version`)
- [ ] AWS CLI configured (`aws configure`)
- [ ] Docker installed (`docker --version`)
- [ ] Terraform installed (`terraform --version`)
- [ ] Git configured (`git --version`)
- [ ] OpenWeather API key obtained
- [ ] (Optional) Domain name registered

### Local Testing
- [ ] Application runs locally with Docker
- [ ] Health endpoint responds (`curl http://localhost:8080/health`)
- [ ] Weather API works (`curl http://localhost:8080/api/weather?city=London`)
- [ ] Frontend displays correctly

## Phase 1: Container Registry (ECR)

- [ ] ECR repository created
- [ ] Docker image built
- [ ] Authenticated with ECR
- [ ] Image pushed to ECR (tagged: latest)
- [ ] Image pushed to ECR (tagged: v1.0.0)
- [ ] Image scan completed (no critical vulnerabilities)

**Verification Command**:
```bash
aws ecr describe-images --repository-name weather-app --region us-east-1
```

## Phase 2: Terraform Backend

- [ ] S3 bucket created for Terraform state
- [ ] S3 bucket versioning enabled
- [ ] S3 bucket encryption enabled
- [ ] S3 bucket public access blocked
- [ ] DynamoDB table created for state locking
- [ ] Backend configuration updated in `backend.tf`

**Verification Commands**:
```bash
aws s3 ls | grep terraform-state
aws dynamodb describe-table --table-name terraform-lock
```

## Phase 3: Infrastructure Deployment

### Terraform Configuration
- [ ] `terraform.tfvars` created with correct values
- [ ] AWS region set correctly
- [ ] OpenWeather API key added
- [ ] Domain name configured (if using)
- [ ] Environment set (prod/staging)

### Terraform Execution
- [ ] `terraform init` successful
- [ ] `terraform validate` passed
- [ ] `terraform fmt` applied
- [ ] `terraform plan` reviewed (~50 resources)
- [ ] `terraform apply` completed (10-15 minutes)
- [ ] Outputs saved to file

**Verification Commands**:
```bash
terraform output > deployment-outputs.txt
terraform show | grep "resource \"aws"
```

## Phase 4: ECS Deployment

### ECS Cluster
- [ ] Cluster created and active
- [ ] Container Insights enabled
- [ ] Fargate capacity provider configured

### ECS Service
- [ ] Service created
- [ ] 2 tasks running
- [ ] Tasks healthy (passed health checks)
- [ ] Service connected to target group

### Application Load Balancer
- [ ] ALB created and active
- [ ] Target group created
- [ ] Health checks configured
- [ ] Targets registered and healthy

**Verification Commands**:
```bash
aws ecs describe-clusters --clusters weather-app-cluster
aws ecs list-tasks --cluster weather-app-cluster --service-name weather-app-service
aws elbv2 describe-target-health --target-group-arn $(terraform output -raw target_group_arn)
```

## Phase 5: Application Testing

### Endpoint Testing
- [ ] Health endpoint: `curl $APP_URL/health`
- [ ] Frontend loads: `curl -I $APP_URL/`
- [ ] Weather API: `curl $APP_URL/api/weather?city=London`
- [ ] Forecast API: `curl $APP_URL/api/forecast?city=Paris`

### Browser Testing
- [ ] Open application in browser
- [ ] Search for a city (e.g., "London")
- [ ] Weather data displays correctly
- [ ] 5-day forecast shows
- [ ] Backend status shows "Healthy"
- [ ] No console errors

**Application URL**: _________________

## Phase 6: Monitoring Setup

### CloudWatch
- [ ] Log group created: `/ecs/weather-app-prod`
- [ ] Logs streaming from containers
- [ ] Container Insights enabled
- [ ] ALB metrics available

### CloudWatch Alarms
- [ ] CPU utilization alarm created
- [ ] Memory utilization alarm created
- [ ] Health check alarm created
- [ ] (Optional) Certificate expiry alarm

### SNS Notifications
- [ ] SNS topic created
- [ ] Email subscription added
- [ ] Email subscription confirmed
- [ ] Test notification sent

**Verification Commands**:
```bash
aws logs tail /ecs/weather-app-prod --follow
aws cloudwatch describe-alarms --state-value ALARM
```

## Phase 7: Auto-Scaling Configuration

- [ ] Auto-scaling target created
- [ ] CPU scaling policy active
- [ ] Memory scaling policy active
- [ ] Minimum capacity: 2 tasks
- [ ] Maximum capacity: 10 tasks
- [ ] Scaling test performed

**Test Auto-Scaling**:
```bash
# Generate load
for i in {1..1000}; do curl -s $APP_URL/api/weather?city=London & done

# Watch tasks scale
watch -n 5 'aws ecs describe-services --cluster weather-app-cluster --services weather-app-service --query "services[0].{desired:desiredCount,running:runningCount}"'
```

- [ ] Tasks scaled up during load test
- [ ] Tasks scaled down after load test

## Phase 8: CI/CD Setup

### GitHub Configuration
- [ ] Repository connected
- [ ] AWS_ACCESS_KEY_ID secret added
- [ ] AWS_SECRET_ACCESS_KEY secret added
- [ ] OPENWEATHER_API_KEY secret added
- [ ] (Optional) DOMAIN_NAME secret added

### CI Pipeline
- [ ] Push triggers CI workflow
- [ ] Linting passes
- [ ] Tests pass
- [ ] Security scans complete
- [ ] Docker image builds
- [ ] Image pushes to ECR
- [ ] Terraform validates

### CD Pipeline
- [ ] CI success triggers CD
- [ ] Terraform applies successfully
- [ ] ECS service updates
- [ ] Health checks pass
- [ ] Smoke tests pass

**Test CI/CD**:
- [ ] Make a small code change
- [ ] Push to GitHub
- [ ] CI workflow completes
- [ ] CD workflow deploys
- [ ] Application updates successfully

## Phase 9: SSL/TLS Setup (Optional)

- [ ] Domain name configured in Route 53
- [ ] Hosted zone created
- [ ] ACM certificate requested
- [ ] DNS validation records added
- [ ] Certificate issued (status: ISSUED)
- [ ] HTTPS listener created on ALB
- [ ] HTTP redirects to HTTPS
- [ ] Application accessible via https://your-domain.com

**Verification Commands**:
```bash
aws acm describe-certificate --certificate-arn $(terraform output -raw acm_certificate_arn)
curl -I https://your-domain.com
```

## Phase 10: Disaster Recovery Setup

### Secondary Region
- [ ] Secondary ECR repository created (us-west-2)
- [ ] Docker image pushed to secondary ECR
- [ ] Secondary ECS cluster created
- [ ] Secondary region infrastructure deployed

### Route 53 Failover
- [ ] Primary health check created
- [ ] Secondary health check created
- [ ] PRIMARY record created (us-east-1)
- [ ] SECONDARY record created (us-west-2)
- [ ] Both health checks passing

### DR Testing
- [ ] Documented baseline performance
- [ ] Simulated primary region failure
- [ ] Failover occurred (3-5 minutes)
- [ ] Application accessible from secondary
- [ ] Primary region restored
- [ ] Automatic failback occurred
- [ ] DR drill documented

**DR Test Commands**:
```bash
# Simulate failure
aws ecs update-service --cluster weather-app-cluster --service weather-app-service --desired-count 0 --region us-east-1

# Monitor failover
watch -n 10 'dig +short your-domain.com'

# Restore
aws ecs update-service --cluster weather-app-cluster --service weather-app-service --desired-count 2 --region us-east-1
```

- [ ] DR drill successful
- [ ] RTO measured: _______ minutes
- [ ] Issues documented and resolved

## Phase 11: Security Hardening

### Network Security
- [ ] Security groups reviewed
- [ ] Unnecessary ports closed
- [ ] VPC flow logs enabled (optional)
- [ ] WAF configured (optional)

### IAM Security
- [ ] Least-privilege policies applied
- [ ] No wildcard permissions
- [ ] MFA enabled for console access
- [ ] Access keys rotated

### Secrets Management
- [ ] API keys in Secrets Manager
- [ ] No secrets in code or logs
- [ ] Rotation policy documented

### Container Security
- [ ] Running as non-root user
- [ ] Image vulnerability scan passed
- [ ] No critical vulnerabilities

**Security Audit**:
```bash
# Scan image
docker scan $(terraform output -raw ecr_repository_url):latest

# Review IAM policies
aws iam get-role-policy --role-name weather-app-prod-ecs-task-role --policy-name weather-app-prod-ecs-task-policy
```

## Phase 12: Production Readiness

### Documentation
- [ ] README.md reviewed
- [ ] DEPLOYMENT_GUIDE.md followed
- [ ] Runbook created for incidents
- [ ] Architecture diagram updated
- [ ] Contact information documented

### Monitoring
- [ ] Dashboard created in CloudWatch
- [ ] Alerts configured
- [ ] On-call rotation established
- [ ] Incident response plan documented

### Backups
- [ ] Terraform state backed up
- [ ] Configuration backed up in Git
- [ ] (If applicable) Database backups configured

### Performance
- [ ] Load testing performed
- [ ] Performance baseline established
- [ ] Bottlenecks identified and addressed
- [ ] Cost optimization applied

### Compliance
- [ ] Security review completed
- [ ] Compliance requirements met
- [ ] Audit logging enabled (CloudTrail)
- [ ] Data retention policies configured

## Go-Live Checklist

### Pre-Launch (T-1 Day)
- [ ] All tests passing
- [ ] Monitoring confirmed working
- [ ] Backup procedures tested
- [ ] DR drill completed successfully
- [ ] Team trained on operations
- [ ] Support channels ready

### Launch Day (T-0)
- [ ] Final deployment to production
- [ ] Smoke tests passed
- [ ] Monitoring active
- [ ] Team on standby
- [ ] Status page updated

### Post-Launch (T+1 Hour)
- [ ] No critical errors in logs
- [ ] Performance metrics normal
- [ ] User reports monitored
- [ ] No alerts triggered

### Post-Launch (T+24 Hours)
- [ ] Daily review completed
- [ ] Cost tracking verified
- [ ] Performance stable
- [ ] Issues documented

### Post-Launch (T+1 Week)
- [ ] Weekly review completed
- [ ] Optimization opportunities identified
- [ ] Documentation updated
- [ ] Team retrospective held

## Ongoing Maintenance

### Daily
- [ ] Check CloudWatch dashboard
- [ ] Review error logs
- [ ] Monitor costs
- [ ] Check health status

### Weekly
- [ ] Review security scans
- [ ] Analyze performance trends
- [ ] Check for dependency updates
- [ ] Review access logs

### Monthly
- [ ] DR drill
- [ ] Cost optimization review
- [ ] Security audit
- [ ] Update documentation
- [ ] Rotate credentials

### Quarterly
- [ ] Full security review
- [ ] Architecture review
- [ ] Capacity planning
- [ ] Disaster recovery test
- [ ] Training updates

## Troubleshooting Checklist

If something goes wrong:

### Application Not Responding
- [ ] Check ECS service status
- [ ] Check task status
- [ ] Review CloudWatch logs
- [ ] Check ALB target health
- [ ] Verify security groups

### High Costs
- [ ] Review CloudWatch billing dashboard
- [ ] Check running task count
- [ ] Review data transfer costs
- [ ] Identify unused resources
- [ ] Apply cost optimization

### Performance Issues
- [ ] Check CPU/memory metrics
- [ ] Review slow API requests
- [ ] Check OpenWeather API limits
- [ ] Scale up tasks if needed
- [ ] Analyze CloudWatch insights

### Deployment Failures
- [ ] Check CI/CD logs
- [ ] Verify AWS credentials
- [ ] Check Terraform state
- [ ] Review ECS deployment logs
- [ ] Rollback if necessary

## Success Criteria

Your deployment is successful when:

✅ Application is accessible via public URL  
✅ All endpoints responding correctly  
✅ No errors in CloudWatch logs  
✅ Health checks passing  
✅ Auto-scaling working  
✅ CI/CD deploying successfully  
✅ Monitoring and alerts active  
✅ DR tested and working  
✅ Cost within budget  
✅ Team trained and confident  

## Notes and Issues

Use this space to document any issues encountered and their resolutions:

**Date**: _________  
**Issue**: _______________________________________________  
**Resolution**: __________________________________________  
**Time to Resolve**: ______________________________________  

---

**Deployment Started**: __________  
**Deployment Completed**: __________  
**Total Time**: __________  
**Deployed By**: __________  
**Production URL**: __________  

---

**Status**: ⬜ Not Started | ⬜ In Progress | ⬜ Complete  
**Next Review Date**: __________
