resource "awscc_kinesis_channel" "raw" {
  channel_name               = "${var.name_prefix}-archive"
  service_execution_role_arn = aws_iam_role.delivery.arn

  stream_configuration_list = [{
    stream_arn = var.stream_arn
    record_configuration = {
      record_format_type = "JSON"
    }
  }]

  s3_destination_configuration = {
    data_freshness_in_seconds = var.delivery_freshness_seconds

    storage_configuration = {
      bucket_arn            = aws_s3_bucket.raw.arn
      expected_bucket_owner = var.aws_account_id
      compression_type      = "GZIP"
      storage_class         = "STANDARD"
      output_key_template   = "raw/year=!{yyyy}/month=!{MM}/day=!{dd}/hour=!{HH}/!{stream-name}-!{channel-id}!{extension:.json.gz}"
    }

    # SQS DLQ와 별도로, S3 직접 전달의 실패 정보를 다른 prefix에 보관합니다.
    dead_letter_queue_s3_configuration = {
      bucket_arn            = aws_s3_bucket.raw.arn
      expected_bucket_owner = var.aws_account_id
      error_output_prefix   = "delivery-errors/"
    }
  }

  logging_configuration = {
    cloudwatch_logs = {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.delivery.name
      log_stream_name = aws_cloudwatch_log_stream.delivery.name
    }
  }

  # Channel의 encryption_configuration은 생략하고 기존 S3의 SSE-S3를 사용합니다.
  # 소스 스트림은 ingestion 모듈의 고객 관리형 KMS 키로 암호화합니다.
  tags = [for key, value in var.tags : { key = key, value = value }]

  depends_on = [
    time_sleep.delivery_iam_propagation,
    aws_s3_bucket_public_access_block.raw,
    aws_s3_bucket_server_side_encryption_configuration.raw,
    aws_s3_bucket_versioning.raw,
    aws_s3_bucket_policy.raw_https_only
  ]
}
