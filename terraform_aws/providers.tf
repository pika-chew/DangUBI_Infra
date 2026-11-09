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

# 기존 state에 남은 Kinesis Channel을 삭제할 때까지 AWSCC provider를 유지합니다.
# 실제 삭제 적용 후 state에서 Channel이 사라지면 별도로 정리할 수 있습니다.
provider "awscc" {
  region = var.aws_region
}
