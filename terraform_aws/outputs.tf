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
  value       = module.delivery.processed_bucket_name
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
  value       = module.delivery.queue_url
}

output "ingestion_queue_arn" {
  description = "전처리 Lambda 전송 권한에 사용할 SQS ARN"
  value       = module.delivery.queue_arn
}

output "ingestion_dlq_url" {
  description = "처리 실패 메시지가 모이는 DLQ URL"
  value       = module.delivery.dlq_url
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

output "processing_ci_function_name" {
  description = "Jenkins 검증용 Lambda 이름"
  value       = module.processing.ci_function_name
}

output "processing_ci_function_arn" {
  description = "Jenkins 검증용 Lambda ARN"
  value       = module.processing.ci_function_arn
}

output "processing_ci_log_group" {
  description = "Jenkins 검증용 Lambda 로그 그룹"
  value       = module.processing.ci_function_log_group_name
}

output "processing_ci_queue_url" {
  description = "Jenkins 검증 결과 확인용 SQS URL"
  value       = module.delivery.ci_queue_url
}

output "processing_ci_queue_arn" {
  description = "Jenkins 검증 결과 확인용 SQS ARN"
  value       = module.delivery.ci_queue_arn
}

output "processing_ci_processed_bucket_name" {
  description = "Jenkins 검증 결과 확인용 S3 버킷 이름"
  value       = module.delivery.ci_processed_bucket_name
}

output "processing_firehose_stream_name" {
  description = "서비스 Lambda용 Firehose 이름"
  value       = module.delivery.firehose_stream_name
}

output "processing_firehose_stream_arn" {
  description = "서비스 Firehose 쓰기 권한 범위를 제한할 ARN"
  value       = module.delivery.firehose_stream_arn
}

output "processing_firehose_log_group" {
  description = "서비스 Firehose의 S3 전달 오류 로그 그룹"
  value       = module.delivery.firehose_log_group_name
}

output "processing_ci_firehose_stream_name" {
  description = "CI Lambda용 테스트 Firehose 이름"
  value       = module.delivery.ci_firehose_stream_name
}

output "processing_ci_firehose_stream_arn" {
  description = "CI Firehose 쓰기 권한 범위를 제한할 ARN"
  value       = module.delivery.ci_firehose_stream_arn
}

output "processing_ci_firehose_log_group" {
  description = "CI Firehose의 S3 전달 오류 로그 그룹"
  value       = module.delivery.ci_firehose_log_group_name
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
