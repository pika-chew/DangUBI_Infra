output "repository_url" {
  description = "백엔드/CI가 Java Lambda 이미지를 업로드할 ECR 주소"
  value       = aws_ecr_repository.preprocess.repository_url
}

output "repository_name" {
  description = "Java Lambda ECR 저장소 이름"
  value       = aws_ecr_repository.preprocess.name
}

output "processed_bucket_name" {
  description = "SQS 메시지 본문을 보관하는 가공 데이터 버킷 이름"
  value       = aws_s3_bucket.processed.id
}

output "processed_bucket_arn" {
  description = "가공 데이터 버킷 ARN"
  value       = aws_s3_bucket.processed.arn
}

output "queue_url" {
  description = "수집 워커가 폴링할 SQS URL"
  value       = aws_sqs_queue.ingestion.url
}

output "queue_name" {
  description = "CloudWatch 지표에 사용할 수집 큐 이름"
  value       = aws_sqs_queue.ingestion.name
}

output "dlq_name" {
  description = "CloudWatch 지표에 사용할 DLQ 이름"
  value       = aws_sqs_queue.ingestion_dlq.name
}

output "queue_arn" {
  description = "전처리 Lambda 전송 권한에 사용할 SQS ARN"
  value       = aws_sqs_queue.ingestion.arn
}

output "dlq_url" {
  description = "처리 실패 메시지를 보관하는 DLQ URL"
  value       = aws_sqs_queue.ingestion_dlq.url
}

output "function_name" {
  description = "Kinesis → SQS 처리 Lambda 이름"
  value       = aws_lambda_function.preprocess.function_name
}

output "function_arn" {
  description = "전처리 Lambda ARN"
  value       = aws_lambda_function.preprocess.arn
}

output "event_source_mapping_id" {
  description = "Kinesis 이벤트 소스 매핑 UUID"
  value       = aws_lambda_event_source_mapping.telemetry.uuid
}

output "function_log_group_name" {
  description = "전처리 Lambda 로그 그룹"
  value       = aws_cloudwatch_log_group.preprocess.name
}
