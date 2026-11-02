variable "name_prefix" {
  description = "루트에서 전달하는 프로젝트·환경 이름 접두사"
  type        = string
}

variable "stream_arn" {
  description = "S3에 원본을 전달할 On-Demand Kinesis 스트림 ARN"
  type        = string
}

variable "stream_kms_key_arn" {
  description = "소스 스트림을 암호화하는 고객 관리형 KMS 키 ARN"
  type        = string
}

variable "delivery_freshness_seconds" {
  description = "S3 전달 freshness(300~900초)"
  type        = number
}

variable "log_retention_days" {
  description = "전달 로그 보관 기간"
  type        = number
}

variable "tags" {
  description = "AWSCC 리소스에도 명시적으로 적용할 공통 태그"
  type        = map(string)
}

variable "aws_account_id" {
  description = "버킷 이름에 포함할 배포 계정 ID"
  type        = string
}

variable "aws_region" {
  description = "버킷 이름에 포함할 배포 리전. 실제 Provider 리전은 루트에서 설정"
  type        = string
}
