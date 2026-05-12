terraform {
  required_version = ">= 1.7.0"

  backend "s3" {
    bucket         = "devsecops-aws-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Project     = "devsecops-aws"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  project     = "devsecops-aws"
  environment = "prod"
}
