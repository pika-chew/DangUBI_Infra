terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.70.0, < 7.0.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.108.0, < 2.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.14.0, < 1.0.0"
    }
  }
}
