terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }

  # Backend para estado remoto (descomentar para producción)
  # backend "s3" {
  #   bucket         = "e-commerce-jfc-terraform-state"
  #   key            = "terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "e-commerce-jfc-terraform-locks"
  # }
}

# Provider AWS
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Project     = "e-commerce-JFC"
      Environment = var.environment_name
    }
  }
}

# Datos de AWS
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}
