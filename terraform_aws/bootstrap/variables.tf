variable "aws_account_id" {
  description = "state 버킷을 관리할 프로젝트 계정 ID"
  type        = string
  default     = "821527508076"
}

variable "aws_region" {
  description = "state 버킷 리전"
  type        = string
  default     = "ap-northeast-2"
}
