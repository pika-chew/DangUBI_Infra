locals {
  firehose_time_path = "year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"

  firehose_destinations = {
    service = {
      stream_name   = "${var.name_prefix}-processed-firehose"
      data_prefix   = "firehose/processed/"
      errors_prefix = "firehose-errors/"
    }
    ci = {
      stream_name   = "${var.name_prefix}-processed-ci-firehose"
      data_prefix   = "firehose/ci/processed/"
      errors_prefix = "firehose/ci/errors/"
    }
  }
}

# Kinesis 입력을 설정하지 않아 Lambda가 Direct PUT 방식으로 데이터를 직접 보냅니다.
resource "aws_kinesis_firehose_delivery_stream" "processed" {
  for_each = local.firehose_destinations

  name        = each.value.stream_name
  destination = "extended_s3"

  server_side_encryption {
    enabled  = true
    key_type = "AWS_OWNED_CMK"
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose[each.key].arn
    bucket_arn          = aws_s3_bucket.processed.arn
    prefix              = "${each.value.data_prefix}${local.firehose_time_path}"
    error_output_prefix = "${each.value.errors_prefix}!{firehose:error-output-type}/${local.firehose_time_path}"
    buffering_size      = var.firehose_buffering_size_mib
    buffering_interval  = var.firehose_buffering_interval_seconds
    compression_format  = "GZIP"
    file_extension      = ".jsonl.gz"
    s3_backup_mode      = "Disabled"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose[each.key].name
      log_stream_name = aws_cloudwatch_log_stream.firehose[each.key].name
    }
  }

  depends_on = [
    time_sleep.firehose_iam_propagation,
    aws_s3_bucket_public_access_block.processed,
    aws_s3_bucket_server_side_encryption_configuration.processed,
    aws_s3_bucket_versioning.processed,
    aws_s3_bucket_policy.processed_https_only
  ]
}
