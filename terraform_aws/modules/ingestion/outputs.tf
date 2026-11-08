output "stream_kms_key_arn" {
  description = "삭제를 보류한 기존 Kinesis 암호화 키 ARN"
  value       = aws_kms_key.telemetry.arn
}

output "iot_device_connections" {
  description = "차량별 MQTT 접속 정보. 개인키 및 인증서 PEM은 포함하지 않습니다."
  value = {
    for id, thing in aws_iot_thing.vehicle : id => {
      endpoint  = data.aws_iot_endpoint.data.endpoint_address
      deviceId  = id
      thingName = thing.name
      clientId  = thing.name
      topic     = "${var.topic_prefix}/${id}/telemetry"
    }
  }
}

output "iot_device_certificates" {
  description = "CSR로 발급한 공개 클라이언트 인증서. 개인키는 로컬에만 있습니다."
  value       = { for id, cert in aws_iot_certificate.vehicle : id => cert.certificate_pem }
  sensitive   = true
}

output "iot_rule_name" {
  description = "IoT 콘솔에서 확인할 전달 규칙 이름"
  value       = aws_iot_topic_rule.telemetry.name
}

output "iot_rule_arn" {
  description = "서비스 Lambda의 호출 권한을 해당 IoT Rule로 제한할 ARN"
  # Rule 리소스 대신 사전에 계산한 ARN을 전달해 전환 단계의 순환 의존을 피합니다.
  value = local.iot_rule_arn
}

output "iot_error_log_group_name" {
  description = "IoT 규칙의 메시지 전달 오류 로그 그룹"
  value       = aws_cloudwatch_log_group.iot_errors.name
}
