terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.108"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }
}
