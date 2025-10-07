# Docker Commands Reference

Complete guide to building, running, and managing the weather app container.

## Table of Contents

- [Local Development](#local-development)
- [Building Images](#building-images)
- [Running Containers](#running-containers)
- [ECR Integration](#ecr-integration)
- [Debugging](#debugging)
- [Best Practices](#best-practices)

## Local Development

### Build and Run Locally

```bash
# Navigate to app directory
cd app

# Build the image
docker build -t weather-app:dev .

# Run with environment variables
docker run -d \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key_here \
  -e FLASK_ENV=development \
  --name weather-app-dev \
  weather-app:dev

# View logs
docker logs -f weather-app-dev

# Access application
open http://localhost:8080
```

### Development with Hot Reload

```bash
# Mount source code for live updates
docker run -d \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key_here \
  -e FLASK_ENV=development \
  -v $(pwd)/backend:/app/backend \
  -v $(pwd)/frontend:/app/frontend \
  --name weather-app-dev \
  weather-app:dev

# Restart after code changes
docker restart weather-app-dev
```

### Using Docker Compose

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    build:
      context: ./app
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - OPENWEATHER_API_KEY=${OPENWEATHER_API_KEY}
      - FLASK_ENV=development
      - PORT=8080
    volumes:
      - ./app/backend:/app/backend
      - ./app/frontend:/app/frontend
    restart: unless-stopped
```

Run with Docker Compose:

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Rebuild and restart
docker-compose up -d --build
```

## Building Images

### Basic Build

```bash
cd app

# Build with default tag
docker build -t weather-app:latest .

# Build with specific tag
docker build -t weather-app:v1.0.0 .

# Build with multiple tags
docker build -t weather-app:latest -t weather-app:v1.0.0 .
```

### Build with Build Arguments

```bash
# Build with custom Python version
docker build \
  --build-arg PYTHON_VERSION=3.11 \
  -t weather-app:py311 .

# Build with custom port
docker build \
  --build-arg PORT=5000 \
  -t weather-app:port5000 .
```

### Multi-Platform Build

```bash
# Build for multiple architectures
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t weather-app:multiarch \
  --push .

# Build for ARM (Apple Silicon)
docker buildx build \
  --platform linux/arm64 \
  -t weather-app:arm64 .
```

### Optimized Production Build

```bash
# Build with optimization flags
docker build \
  --no-cache \
  --pull \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t weather-app:prod .

# Verify image size
docker images weather-app:prod
```

## Running Containers

### Basic Run

```bash
# Run in detached mode
docker run -d \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key \
  --name weather-app \
  weather-app:latest

# Run in interactive mode
docker run -it \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key \
  weather-app:latest

# Run with automatic removal
docker run --rm \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key \
  weather-app:latest
```

### Advanced Run Options

```bash
# Run with resource limits
docker run -d \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key \
  --memory="512m" \
  --cpus="0.5" \
  --name weather-app \
  weather-app:latest

# Run with health check override
docker run -d \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key \
  --health-cmd="curl -f http://localhost:8080/health || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --name weather-app \
  weather-app:latest

# Run with restart policy
docker run -d \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key \
  --restart=always \
  --name weather-app \
  weather-app:latest
```

### Environment Variables

```bash
# From file
docker run -d \
  -p 8080:8080 \
  --env-file .env \
  --name weather-app \
  weather-app:latest

# Multiple environment variables
docker run -d \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key \
  -e FLASK_ENV=production \
  -e PORT=8080 \
  -e LOG_LEVEL=INFO \
  --name weather-app \
  weather-app:latest
```

### Volume Mounts

```bash
# Mount configuration file
docker run -d \
  -p 8080:8080 \
  -v $(pwd)/config.json:/app/config.json:ro \
  -e OPENWEATHER_API_KEY=your_api_key \
  --name weather-app \
  weather-app:latest

# Mount logs directory
docker run -d \
  -p 8080:8080 \
  -v $(pwd)/logs:/app/logs \
  -e OPENWEATHER_API_KEY=your_api_key \
  --name weather-app \
  weather-app:latest
```

## ECR Integration

### Authenticate with ECR

```bash
# Get ECR login token
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

# Alternative: using AWS CLI v1
$(aws ecr get-login --no-include-email --region us-east-1)
```

### Tag for ECR

```bash
# Get ECR repository URI
ECR_REPO_URI="123456789012.dkr.ecr.us-east-1.amazonaws.com/weather-app"

# Tag local image for ECR
docker tag weather-app:latest $ECR_REPO_URI:latest
docker tag weather-app:latest $ECR_REPO_URI:v1.0.0
docker tag weather-app:latest $ECR_REPO_URI:$(git rev-parse --short HEAD)
```

### Push to ECR

```bash
# Push specific tag
docker push $ECR_REPO_URI:latest

# Push multiple tags
docker push $ECR_REPO_URI:v1.0.0
docker push $ECR_REPO_URI:$(git rev-parse --short HEAD)

# Push all tags
docker push --all-tags $ECR_REPO_URI
```

### Pull from ECR

```bash
# Pull latest version
docker pull $ECR_REPO_URI:latest

# Pull specific version
docker pull $ECR_REPO_URI:v1.0.0

# Pull and run
docker run -d \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key \
  --name weather-app \
  $ECR_REPO_URI:latest
```

### ECR Lifecycle Management

```bash
# List all images in repository
aws ecr list-images \
  --repository-name weather-app \
  --region us-east-1

# Delete specific image
aws ecr batch-delete-image \
  --repository-name weather-app \
  --image-ids imageTag=old-version \
  --region us-east-1

# Delete untagged images
UNTAGGED_IMAGES=$(aws ecr list-images \
  --repository-name weather-app \
  --filter "tagStatus=UNTAGGED" \
  --query 'imageIds[*]' \
  --output json)

aws ecr batch-delete-image \
  --repository-name weather-app \
  --image-ids "$UNTAGGED_IMAGES" \
  --region us-east-1
```

## Debugging

### Inspect Container

```bash
# View container details
docker inspect weather-app

# Check resource usage
docker stats weather-app

# View container processes
docker top weather-app

# Check container health
docker inspect --format='{{json .State.Health}}' weather-app | jq
```

### Container Logs

```bash
# View logs
docker logs weather-app

# Follow logs
docker logs -f weather-app

# View last 100 lines
docker logs --tail 100 weather-app

# View logs since specific time
docker logs --since 10m weather-app

# View logs with timestamps
docker logs -t weather-app
```

### Execute Commands in Container

```bash
# Interactive shell
docker exec -it weather-app /bin/bash

# Run single command
docker exec weather-app curl http://localhost:8080/health

# Check Python version
docker exec weather-app python --version

# View environment variables
docker exec weather-app env

# Check disk usage
docker exec weather-app df -h

# Check running processes
docker exec weather-app ps aux
```

### Network Debugging

```bash
# Check port mapping
docker port weather-app

# Test connectivity from host
curl -v http://localhost:8080/health

# Test connectivity from another container
docker run --rm curlimages/curl:latest \
  curl http://host.docker.internal:8080/health

# Check container IP
docker inspect weather-app | grep IPAddress
```

### Performance Testing

```bash
# CPU and memory monitoring
docker stats weather-app --no-stream

# Continuous monitoring
docker stats weather-app

# Load test the application
docker run --rm williamyeh/hey \
  -n 1000 -c 10 http://host.docker.internal:8080/api/weather?city=London

# Check container events
docker events --filter container=weather-app
```

## Container Management

### Stop and Start

```bash
# Stop container
docker stop weather-app

# Start stopped container
docker start weather-app

# Restart container
docker restart weather-app

# Pause container
docker pause weather-app

# Unpause container
docker unpause weather-app
```

### Remove Containers

```bash
# Remove stopped container
docker rm weather-app

# Force remove running container
docker rm -f weather-app

# Remove all stopped containers
docker container prune

# Remove all containers (careful!)
docker rm -f $(docker ps -aq)
```

### Image Management

```bash
# List images
docker images

# List all images (including intermediates)
docker images -a

# Remove image
docker rmi weather-app:latest

# Remove dangling images
docker image prune

# Remove all unused images
docker image prune -a

# Check image history
docker history weather-app:latest

# Export image
docker save weather-app:latest | gzip > weather-app.tar.gz

# Import image
gunzip -c weather-app.tar.gz | docker load
```

## Best Practices

### Security

```bash
# Scan image for vulnerabilities
docker scan weather-app:latest

# Run as non-root user (already configured in Dockerfile)
docker run -d \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key \
  --read-only \
  --tmpfs /tmp \
  --name weather-app \
  weather-app:latest

# Limit capabilities
docker run -d \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --name weather-app \
  weather-app:latest
```

### Resource Optimization

```bash
# Run with resource limits
docker run -d \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key \
  --memory="512m" \
  --memory-reservation="256m" \
  --cpus="0.5" \
  --pids-limit=100 \
  --name weather-app \
  weather-app:latest

# Monitor resource usage
watch -n 1 'docker stats weather-app --no-stream'
```

### CI/CD Integration

```bash
# Build script for CI/CD
#!/bin/bash
set -e

IMAGE_NAME="weather-app"
IMAGE_TAG=${1:-latest}
ECR_REPO_URI=${ECR_REPO_URI}

echo "Building image: ${IMAGE_NAME}:${IMAGE_TAG}"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .

echo "Tagging for ECR"
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REPO_URI}:${IMAGE_TAG}

echo "Running tests"
docker run --rm \
  -e OPENWEATHER_API_KEY=test_key \
  ${IMAGE_NAME}:${IMAGE_TAG} \
  python -m pytest tests/

echo "Pushing to ECR"
aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR_REPO_URI}
docker push ${ECR_REPO_URI}:${IMAGE_TAG}

echo "✅ Build and push complete"
```

### Cleanup Script

```bash
#!/bin/bash
# cleanup-docker.sh

echo "Cleaning up Docker resources..."

# Stop all running containers
docker stop $(docker ps -q) 2>/dev/null || true

# Remove all containers
docker container prune -f

# Remove dangling images
docker image prune -f

# Remove unused volumes
docker volume prune -f

# Remove unused networks
docker network prune -f

# Show disk usage
docker system df

echo "✅ Cleanup complete"
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs weather-app

# Try running interactively
docker run -it --rm \
  -e OPENWEATHER_API_KEY=your_api_key \
  weather-app:latest

# Check if port is already in use
lsof -i :8080

# Verify environment variables
docker run --rm \
  weather-app:latest \
  env
```

### High Memory Usage

```bash
# Check memory stats
docker stats weather-app --no-stream

# Inspect memory limit
docker inspect weather-app | grep -i memory

# Set memory limit
docker update --memory="512m" weather-app

# Restart with new limit
docker stop weather-app
docker rm weather-app
docker run -d \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your_api_key \
  --memory="512m" \
  --name weather-app \
  weather-app:latest
```

### Network Issues

```bash
# Check container networking
docker network inspect bridge

# Test DNS resolution
docker exec weather-app nslookup google.com

# Test external connectivity
docker exec weather-app curl -v https://api.openweathermap.org

# Check firewall rules
sudo iptables -L -n
```

## Quick Reference

### Most Used Commands

```bash
# Build
docker build -t weather-app:latest .

# Run
docker run -d -p 8080:8080 -e OPENWEATHER_API_KEY=key --name weather-app weather-app:latest

# Logs
docker logs -f weather-app

# Shell
docker exec -it weather-app /bin/bash

# Stop
docker stop weather-app

# Remove
docker rm weather-app

# Cleanup
docker system prune -f
```

### Environment Variables

```bash
OPENWEATHER_API_KEY=your_api_key_here
PORT=8080
FLASK_ENV=production
LOG_LEVEL=INFO
AWS_DEFAULT_REGION=us-east-1
```

### Useful Aliases

Add to `.bashrc` or `.zshrc`:

```bash
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dlog='docker logs -f'
alias dexec='docker exec -it'
alias dclean='docker system prune -af'
```

---

For more information, see:
- [Docker Documentation](https://docs.docker.com/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/)
