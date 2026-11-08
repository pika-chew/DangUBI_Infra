variable "processing_image_uri" {
  description = "Lambda용 arm64 Java 이미지 URI. ECR만 먼저 생성할 때는 null, 전체 배포 전 repository@sha256:... 설정"
  type        = string
  default     = null

  validation {
    condition     = var.processing_image_uri == null ? true : can(regex("^[0-9]{12}\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/[a-z0-9._/-]+@sha256:[0-9a-f]{64}$", var.processing_image_uri))
    error_message = "processing_image_uri는 private ECR repository@sha256:<64자리 소문자 hex> 형식이어야 합니다."
  }
}

variable "aws_region" {
  description = "AWS 리소스를 생성할 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_account_id" {
  description = "실수로 다른 계정에 배포하지 않도록 제한할 계정 ID (pika-ubi)"
  type        = string
  default     = "821527508076"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS 계정 ID는 12자리 숫자여야 합니다."
  }
}

variable "project_name" {
  description = "AWS 리소스 이름에 사용할 프로젝트명"
  type        = string
  default     = "ubi"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.project_name))
    error_message = "프로젝트명은 영문 소문자로 시작하는 2~20자의 소문자, 숫자, 하이픈이어야 합니다."
  }
}

variable "environment" {
  description = "배포 환경 이름"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "환경은 dev, stage, prod 중 하나여야 합니다."
  }
}

variable "sqs_visibility_timeout_seconds" {
  description = "수집 워커가 메시지를 처리하는 동안 다른 워커에게 숨기는 시간. 실제 처리 시간에 맞춰 조정"
  type        = number
  default     = 120

  validation {
    condition     = var.sqs_visibility_timeout_seconds >= 0 && var.sqs_visibility_timeout_seconds <= 43200 && floor(var.sqs_visibility_timeout_seconds) == var.sqs_visibility_timeout_seconds
    error_message = "Visibility timeout은 0~43200초 사이의 정수여야 합니다."
  }
}

variable "archive_delivery_freshness_seconds" {
  description = "S3 직접 전달의 목표 최대 버퍼링 시간(초). 지원 범위는 5~15분"
  type        = number
  default     = 300

  validation {
    condition     = var.archive_delivery_freshness_seconds >= 300 && var.archive_delivery_freshness_seconds <= 900 && floor(var.archive_delivery_freshness_seconds) == var.archive_delivery_freshness_seconds
    error_message = "S3 전달 freshness는 300~900초 사이의 정수여야 합니다."
  }
}

variable "cloudwatch_log_retention_days" {
  description = "S3 전달·Lambda·IoT 규칙 오류 로그 보관 기간(일)"
  type        = number
  default     = 7

  validation {
    condition     = contains([7, 14, 30, 60, 90], var.cloudwatch_log_retention_days)
    error_message = "로그 보관 기간은 7, 14, 30, 60, 90일 중 하나여야 합니다."
  }
}

variable "processing_batch_size" {
  description = "Kinesis → Lambda 한 번 호출 시 최대 레코드 수"
  type        = number
  default     = 100

  validation {
    condition     = var.processing_batch_size >= 1 && var.processing_batch_size <= 10000 && floor(var.processing_batch_size) == var.processing_batch_size
    error_message = "Lambda Kinesis 배치 크기는 1~10000 사이의 정수여야 합니다."
  }
}

variable "processing_consumer_enabled" {
  description = "Kinesis → Lambda 소비 활성화. false로 변경하면 폴링을 중지"
  type        = bool
  default     = true
}

variable "sqs_age_alarm_threshold_seconds" {
  description = "수집 큐의 가장 오래된 메시지 나이에 대한 알람 임계값(초)"
  type        = number
  default     = 300

  validation {
    condition     = var.sqs_age_alarm_threshold_seconds > 0
    error_message = "메시지 나이 임계값은 0보다 커야 합니다."
  }
}

variable "cloudwatch_alarm_action_arns" {
  description = "기존 SNS 토픽 등 알람 대상 ARN. 기본값은 상태 표시만 하고 외부 알림은 보내지 않음"
  type        = list(string)
  default     = []
}

variable "iot_device_csr_paths" {
  description = "차량 ID별 CSR 파일 경로. Terraform 실행 디렉토리 기준"
  type        = map(string)
  default = {
    vehicle-001 = "certificates/vehicle-001/request.csr"
  }

  validation {
    condition     = length(var.iot_device_csr_paths) > 0 && alltrue([for id in keys(var.iot_device_csr_paths) : can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$", id))])
    error_message = "차량 ID는 영숫자로 시작하는 1~64자의 영숫자, 밑줄, 하이픈이어야 합니다."
  }
}

variable "iot_rule_enabled" {
  description = "기존 서비스 Lambda를 직접 호출하는 IoT Core Topic Rule 활성화 여부"
  type        = bool
  default     = true
  nullable    = false

  validation {
    condition     = !var.iot_rule_enabled || var.s3_queue_notifications_enabled
    error_message = "IoT Rule을 활성화하려면 서비스 S3→SQS 알림도 활성화해야 합니다. 준비만 할 때는 iot_rule_enabled=false로 두세요."
  }
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
  description = "서비스 가공 S3의 SQS 알림 활성화. 소비자 전환 준비가 끝난 뒤 true로 설정"
  type        = bool
  default     = false
  nullable    = false
}

variable "ci_s3_queue_notifications_enabled" {
  description = "CI 가공 S3의 테스트 SQS 알림 활성화. 새 Lambda 이미지 준비 후 개별 활성화"
  type        = bool
  default     = false
  nullable    = false
}
