terraform {
  required_version = ">= 1.13.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.33.0"
    }
  }

  # bucket / key は terraform init 時に -backend-config で渡す
  backend "s3" {
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "ghost-writer"
      ManagedBy = "terraform"
    }
  }
}
