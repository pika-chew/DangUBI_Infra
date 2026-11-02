resource "aws_kinesis_stream" "telemetry" {
  name             = "${var.name_prefix}-telemetry"
  retention_period = 24 # 기본값 24, 최대는 365일 (장애 발생 시 재처리할 수 있는 골든 타임이 되므로 시스템 복구 RTO 기준에 맞춰 설정)

  stream_mode_details {       # Capacity Mode
    stream_mode = "ON_DEMAND" # S3 직접 전달은 On-Demand 스트림만 지원
  }

  encryption_type = "KMS" # 데이터 저장시 암호화 (기본값은 NONE)
  kms_key_id      = aws_kms_key.telemetry.arn

  # IoT Topic Rule이 MQTT 토픽의 차량 ID를 파티션 키로 사용합니다.
}
