variable "name_prefix" {
  description = "루트에서 전달하는 프로젝트·환경 이름 접두사"
  type        = string
}

variable "aws_account_id" {
  description = "가공 데이터 버킷 이름에 포함할 AWS 계정 ID"
  type        = string
}

variable "aws_region" {
  description = "가공 데이터 버킷 이름에 포함할 AWS 리전"
  type        = string
}

variable "log_retention_days" {
  description = "Firehose 전달 오류 로그 보관 기간"
  type        = number
}

variable "visibility_timeout_seconds" {
  description = "수집 워커의 메시지 처리 중 숨김 시간(초)"
  type        = number
}

variable "firehose_buffering_size_mib" {
  description = "서비스·CI Firehose의 S3 전달 버퍼 크기 힌트(MiB)"
  type        = number
  default     = 5

  validation {
    condition     = var.firehose_buffering_size_mib >= 1 && var.firehose_buffering_size_mib <= 128 && floor(var.firehose_buffering_size_mib) == var.firehose_buffering_size_mib
    error_message = "Firehose 버퍼 크기는 1~128 MiB 사이의 정수여야 합니다."
  }
}

variable "firehose_buffering_interval_seconds" {
  description = "서비스·CI Firehose의 S3 전달 버퍼 시간 힌트(초). 종단 간 지연 상한이 아님"
  type        = number
  default     = 60

  validation {
    condition     = var.firehose_buffering_interval_seconds >= 0 && var.firehose_buffering_interval_seconds <= 900 && floor(var.firehose_buffering_interval_seconds) == var.firehose_buffering_interval_seconds
    error_message = "Firehose 버퍼 시간은 0~900초 사이의 정수여야 합니다."
  }
}

variable "s3_queue_notifications_enabled" {
  description = "서비스 가공 S3의 SQS 알림 리소스 생성 여부. 루트에서 명시적으로 전달"
  type        = bool
  default     = false
  nullable    = false
}
