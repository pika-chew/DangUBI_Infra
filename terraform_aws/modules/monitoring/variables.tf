variable "name_prefix" {
  type        = string
  description = "프로젝트·환경 이름 접두사"
}

variable "aws_region" {
  type        = string
  description = "관측 대상 리전"
}

variable "stream_name" {
  type        = string
  description = "Kinesis 스트림 이름"
}

variable "channel_name" {
  type        = string
  description = "S3 직접 전달 Channel 이름"
}

variable "channel_id" {
  type        = string
  description = "S3 직접 전달 Channel ID"
}

variable "delivery_log_group_name" {
  type        = string
  description = "S3 직접 전달 로그 그룹"
}

variable "queue_name" {
  type        = string
  description = "수집 큐 이름"
}

variable "dlq_name" {
  type        = string
  description = "수집 워커용 SQS DLQ 이름"
}

variable "delivery_freshness_seconds" {
  type        = number
  description = "S3 전달 목표 freshness. 두 배 초과 시 지연 경보"
}

variable "queue_age_threshold_seconds" {
  type        = number
  description = "수집 큐 메시지 나이의 경보 임계값"
}

variable "alarm_action_arns" {
  type        = list(string)
  description = "알람·복구 알림을 보낼 기존 SNS 토픽 등의 ARN"
  default     = []
}

variable "processing_function_name" {
  description = "Kinesis → SQS 처리 Lambda 이름"
  type        = string
}

variable "processing_log_group_name" {
  description = "처리 Lambda 로그 그룹"
  type        = string
}

variable "iot_rule_name" {
  description = "IoT Core의 Kinesis 전달 규칙 이름"
  type        = string
}

variable "iot_error_log_group_name" {
  description = "IoT 규칙 오류 로그 그룹"
  type        = string
}
