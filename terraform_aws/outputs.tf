output "processing_repository_url" {
  description = "Java Lambda 이미지 업로드용 ECR 주소"
  value       = module.processing.repository_url
}

output "processing_repository_name" {
  description = "Java Lambda 이미지 업로드용 ECR 저장소 이름"
  value       = module.processing.repository_name
}

output "processed_bucket_name" {
  description = "SQS에 전달할 가공 메시지 본문을 보관하는 S3 버킷 이름"
  value       = module.processing.processed_bucket_name
}

output "raw_bucket_name" {
  description = "원본 데이터를 보관할 S3 버킷 이름"
  value       = module.archive.bucket_name
}

output "kinesis_stream_name" {
  description = "IoT Topic Rule에서 사용할 Kinesis 스트림 이름"
  value       = module.ingestion.stream_name
}

output "kinesis_stream_arn" {
  description = "Lambda와 S3 직접 전달에서 사용할 Kinesis 스트림 ARN"
  value       = module.ingestion.stream_arn
}

output "kinesis_kms_key_arn" {
  description = "Kinesis 소스 스트림의 고객 관리형 KMS 키 ARN"
  value       = module.ingestion.stream_kms_key_arn
}

output "archive_channel_arn" {
  description = "원본 데이터를 S3에 직접 전달하는 Kinesis Channel ARN"
  value       = module.archive.channel_arn
}

output "archive_delivery_log_group" {
  description = "S3 직접 전달의 CloudWatch 로그 그룹"
  value       = module.archive.delivery_log_group_name
}

output "cloudwatch_dashboard_name" {
  description = "파이프라인 CloudWatch 대시보드 이름"
  value       = module.monitoring.dashboard_name
}

output "cloudwatch_alarm_names" {
  description = "생성된 CloudWatch 알람 이름"
  value       = module.monitoring.alarm_names
}

output "ingestion_queue_url" {
  description = "프라이빗 클라우드 수집 워커가 사용할 SQS URL"
  value       = module.processing.queue_url
}

output "ingestion_queue_arn" {
  description = "전처리 Lambda 전송 권한에 사용할 SQS ARN"
  value       = module.processing.queue_arn
}

output "ingestion_dlq_url" {
  description = "처리 실패 메시지가 모이는 DLQ URL"
  value       = module.processing.dlq_url
}

output "processing_function_name" {
  description = "Kinesis → SQS 처리 Lambda 이름"
  value       = module.processing.function_name
}

output "processing_event_source_mapping_id" {
  description = "Kinesis → Lambda 연결 상태 확인에 사용할 UUID"
  value       = module.processing.event_source_mapping_id
}

output "processing_log_group" {
  description = "전처리 Lambda 로그 그룹"
  value       = module.processing.function_log_group_name
}

output "iot_device_connections" {
  description = "시뮬레이터에서 사용할 차량별 MQTT 접속 정보"
  value       = module.ingestion.iot_device_connections
}

output "iot_device_certificates" {
  description = "내보내기 스크립트가 저장할 공개 클라이언트 인증서 PEM"
  value       = module.ingestion.iot_device_certificates
  sensitive   = true
}

output "iot_rule_name" {
  description = "IoT Core의 Kinesis 전달 규칙 이름"
  value       = module.ingestion.iot_rule_name
}

output "iot_error_log_group" {
  description = "IoT 규칙 오류 로그 그룹"
  value       = module.ingestion.iot_error_log_group_name
}
