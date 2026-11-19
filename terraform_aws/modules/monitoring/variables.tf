variable "name_prefix" {
  type        = string
  description = "프로젝트·환경 이름 접두사"
}

variable "aws_region" {
  type        = string
  description = "관측 대상 리전"
}

variable "queue_name" {
  type        = string
  description = "수집 큐 이름"
}

variable "dlq_name" {
  type        = string
  description = "수집 워커용 SQS DLQ 이름"
}

variable "queue_age_threshold_seconds" {
  type        = number
  description = "수집 큐 메시지 나이의 경보 임계값"
}

variable "alarm_action_arns" {
  type        = list(string)
  description = "모듈이 만드는 알람 토픽 외에 추가로 알림을 보낼 SNS 토픽 등의 ARN"
  default     = []
}

variable "slack_workspace_id" {
  type        = string
  description = "AWS Chatbot에 연결한 Slack 워크스페이스 ID(T로 시작). null이면 Slack 전달을 만들지 않음"
  default     = null

  validation {
    condition     = var.slack_workspace_id == null ? true : can(regex("^T[A-Z0-9]{8,}$", var.slack_workspace_id))
    error_message = "Slack 워크스페이스 ID는 T로 시작하는 대문자·숫자여야 합니다. C로 시작하는 값은 채널 ID입니다."
  }
}

variable "slack_channel_id" {
  type        = string
  description = "알람을 받을 Slack 채널 ID(C로 시작). 채널 이름(#...)이 아님"
  default     = null

  validation {
    condition     = var.slack_channel_id == null ? true : can(regex("^[CG][A-Z0-9]{8,}$", var.slack_channel_id))
    error_message = "Slack 채널 ID는 C 또는 G로 시작하는 대문자·숫자여야 합니다. 채널 이름(#...)은 쓸 수 없습니다."
  }
}

variable "processing_function_name" {
  description = "IoT 메시지를 가공해 Firehose로 전달하는 서비스 Lambda 이름"
  type        = string
}

variable "processing_log_group_name" {
  description = "처리 Lambda 로그 그룹"
  type        = string
}

variable "iot_rule_name" {
  description = "IoT Core의 서비스 Lambda 호출 규칙 이름"
  type        = string
}

variable "iot_error_log_group_name" {
  description = "IoT 규칙 오류 로그 그룹"
  type        = string
}

variable "firehose_stream_name" {
  description = "운영 가공 데이터를 S3로 전달하는 Firehose 스트림 이름"
  type        = string
}

variable "firehose_log_group_name" {
  description = "운영 Firehose 전달 오류 로그 그룹. 로그 저장소는 delivery 모듈에서 생성"
  type        = string
}

variable "firehose_freshness_threshold_seconds" {
  description = "Firehose S3 전달 데이터 지연의 경보 임계값(초)"
  type        = number

  validation {
    condition     = var.firehose_freshness_threshold_seconds > 0 && floor(var.firehose_freshness_threshold_seconds) == var.firehose_freshness_threshold_seconds
    error_message = "Firehose 지연 경보 임계값은 양의 정수(초)여야 합니다."
  }
}
