variable "image_uri" {
  description = "백엔드에서 빌드·push한 Lambda 호환 arm64 Java 이미지의 ECR URI. digest로 고정"
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "루트에서 전달하는 프로젝트·환경 이름 접두사"
  type        = string
}

variable "failure_bucket_arn" {
  description = "재시도 소진 시 전체 실패 이벤트를 보관할 S3 버킷 ARN"
  type        = string
}

variable "aws_region" {
  description = "Lambda·ECR 리소스 ARN에 사용할 리전"
  type        = string
}

variable "aws_account_id" {
  description = "실패 이벤트를 보관하는 S3 버킷의 소유 계정"
  type        = string
}

variable "log_retention_days" {
  description = "Lambda 로그 보관 기간"
  type        = number
}

variable "iot_rule_arn" {
  description = "서비스 Lambda 직접 호출을 허용할 IoT Rule ARN. null이면 호출 권한을 생성하지 않음"
  type        = string
  default     = null
}

variable "delivery_destinations" {
  description = "delivery 모듈에서 전달하는 서비스·CI Firehose"
  type = map(object({
    firehose_name = string
    firehose_arn  = string
  }))

  validation {
    condition     = toset(keys(var.delivery_destinations)) == toset(["service", "ci"])
    error_message = "저장·전송 대상은 service와 ci 두 환경을 모두 포함해야 합니다."
  }
}
