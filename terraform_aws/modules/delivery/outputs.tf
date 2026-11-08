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

output "ci_queue_url" {
  description = "CI 결과 확인용 테스트 SQS URL"
  value       = aws_sqs_queue.ingestion_ci.url
}

output "ci_queue_arn" {
  description = "Jenkins의 테스트 SQS 조회 권한을 제한할 ARN"
  value       = aws_sqs_queue.ingestion_ci.arn
}

output "ci_processed_bucket_name" {
  description = "CI 결과 확인용 테스트 S3 버킷 이름"
  value       = aws_s3_bucket.processed_ci.id
}

output "firehose_stream_name" {
  description = "서비스 Lambda가 가공 결과를 전달할 Firehose 이름"
  value       = aws_kinesis_firehose_delivery_stream.processed["service"].name
}

output "firehose_stream_arn" {
  description = "서비스 Firehose 쓰기 권한 범위를 제한할 ARN"
  value       = aws_kinesis_firehose_delivery_stream.processed["service"].arn
}

output "firehose_log_group_name" {
  description = "서비스 Firehose의 S3 전달 오류 로그 그룹"
  value       = aws_cloudwatch_log_group.firehose["service"].name
}

output "ci_firehose_stream_name" {
  description = "CI Lambda가 가공 결과를 전달할 테스트 Firehose 이름"
  value       = aws_kinesis_firehose_delivery_stream.processed["ci"].name
}

output "ci_firehose_stream_arn" {
  description = "CI Firehose 쓰기 권한 범위를 제한할 ARN"
  value       = aws_kinesis_firehose_delivery_stream.processed["ci"].arn
}

output "ci_firehose_log_group_name" {
  description = "CI Firehose의 S3 전달 오류 로그 그룹"
  value       = aws_cloudwatch_log_group.firehose["ci"].name
}

output "lambda_destinations" {
  description = "processing 모듈이 Lambda 환경 변수와 실행 권한에 사용할 서비스·CI 대상"
  value = {
    service = {
      bucket_name       = aws_s3_bucket.processed.id
      bucket_arn        = aws_s3_bucket.processed.arn
      queue_url         = aws_sqs_queue.ingestion.url
      queue_arn         = aws_sqs_queue.ingestion.arn
      max_message_bytes = aws_sqs_queue.ingestion.max_message_size
      firehose_name     = aws_kinesis_firehose_delivery_stream.processed["service"].name
      firehose_arn      = aws_kinesis_firehose_delivery_stream.processed["service"].arn
    }
    ci = {
      bucket_name       = aws_s3_bucket.processed_ci.id
      bucket_arn        = aws_s3_bucket.processed_ci.arn
      queue_url         = aws_sqs_queue.ingestion_ci.url
      queue_arn         = aws_sqs_queue.ingestion_ci.arn
      max_message_bytes = aws_sqs_queue.ingestion_ci.max_message_size
      firehose_name     = aws_kinesis_firehose_delivery_stream.processed["ci"].name
      firehose_arn      = aws_kinesis_firehose_delivery_stream.processed["ci"].arn
    }
  }

  # Lambda를 연결하기 전에 기존 버킷 보호·암호화 설정이 준비되도록 합니다.
  depends_on = [
    aws_s3_bucket_public_access_block.processed,
    aws_s3_bucket_server_side_encryption_configuration.processed,
    aws_s3_bucket_versioning.processed,
    aws_s3_bucket_policy.processed_https_only,
    aws_s3_bucket_public_access_block.processed_ci,
    aws_s3_bucket_server_side_encryption_configuration.processed_ci,
    aws_s3_bucket_policy.processed_ci_https_only
  ]
}
