# Terraform remote backend configuration
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 backend for storing Terraform state
  backend "s3" {
    bucket         = "weather-app-terraform-state-bucket"
    key            = "weather-app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    
    # These will be set via environment variables or CLI flags
    # AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_primary_region
  
  default_tags {
    tags = {
      Project     = "weather-app"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "cloud-deployment-demo"
    }
  }
}

# Secondary region provider for disaster recovery
provider "aws" {
  alias  = "secondary"
  region = var.aws_secondary_region
  
  default_tags {
    tags = {
      Project     = "weather-app"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "cloud-deployment-demo"
      Region      = "secondary"
    }
  }
}
