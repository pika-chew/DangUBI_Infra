variable "name_prefix" {
  description = "루트에서 전달하는 프로젝트·환경 이름 접두사"
  type        = string
}

variable "aws_region" {
  description = "IoT ARN 및 KMS 서비스 조건에 사용할 리전"
  type        = string
}

variable "aws_account_id" {
  description = "IoT 및 실행 역할을 배포할 계정"
  type        = string
}

variable "device_csrs" {
  description = "차량 ID별 공개 CSR 내용. 개인키를 전달하지 않습니다."
  type        = map(string)
}

variable "topic_prefix" {
  description = "프로젝트/환경/vehicles 형태의 세 단계 MQTT 토픽 접두사"
  type        = string
}

variable "log_retention_days" {
  description = "IoT 규칙 오류 로그 보관 기간"
  type        = number
}

variable "rule_enabled" {
  description = "차량 메시지의 Kinesis 전달 규칙 활성화 여부"
  type        = bool
}
