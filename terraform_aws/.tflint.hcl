config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# 버전 제약은 루트와 bootstrap의 versions.tf에서 관리합니다. --recursive가 모듈 폴더도 검사해 경고가 나지 않도록 끕니다.
rule "terraform_required_version" {
  enabled = false
}

plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
