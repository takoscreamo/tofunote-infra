terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    vercel = {
      source  = "vercel/vercel"
      version = "~> 1.0"
    }
  }
}

# AWS Provider
provider "aws" {
  region = var.aws_region
}

# AWS Provider for us-east-1 (for ACM certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Cloudflare Provider
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Vercel Provider
provider "vercel" {
  api_token = var.vercel_api_token
}
