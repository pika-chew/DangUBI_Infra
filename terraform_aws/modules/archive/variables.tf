variable "name_prefix" {
  description = "루트에서 전달하는 프로젝트·환경 이름 접두사"
  type        = string
}

variable "aws_account_id" {
  description = "버킷 이름에 포함할 배포 계정 ID"
  type        = string
}

variable "aws_region" {
  description = "버킷 이름에 포함할 배포 리전. 실제 Provider 리전은 루트에서 설정"
  type        = string
}
