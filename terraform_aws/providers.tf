provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Kinesis Channel은 공식 Cloud Control Provider로 관리합니다.
# AWS_PROFILE 등 동일한 로컬 인증 설정을 사용합니다.
provider "awscc" {
  region = var.aws_region
}
