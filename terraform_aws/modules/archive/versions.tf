terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.70.0, < 7.0.0"
    }
    # 기존 state의 Channel 삭제를 완료할 때까지 필요합니다.
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.108.0, < 2.0.0"
    }
  }
}
