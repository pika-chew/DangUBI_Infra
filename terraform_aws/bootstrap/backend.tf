terraform {
  backend "s3" {
    bucket              = "ubi-tfstate-821527508076-ap-northeast-2"
    key                 = "bootstrap/terraform.tfstate"
    region              = "ap-northeast-2"
    allowed_account_ids = ["821527508076"]
    encrypt             = true
    use_lockfile        = true
  }
}
