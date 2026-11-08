variable "name_prefix" {
  description = "루트에서 전달하는 프로젝트·환경 이름 접두사"
  type        = string
}

variable "aws_region" {
  description = "IoT 리소스 ARN에 사용할 리전"
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
  description = "서비스 Lambda를 직접 호출하는 차량 메시지 규칙 활성화 여부"
  type        = bool
}

variable "lambda_function_arn" {
  description = "IoT Rule이 직접 호출할 기존 서비스 Lambda ARN"
  type        = string
  nullable    = false

  validation {
    condition = can(regex(
      "^arn:[a-z-]+:lambda:${var.aws_region}:${var.aws_account_id}:function:[A-Za-z0-9_-]+(:[A-Za-z0-9_$-]+)?$",
      var.lambda_function_arn
    ))
    error_message = "IoT Rule에는 동일 계정·리전의 Lambda 함수 ARN이 필요합니다."
  }
}
