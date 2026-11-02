locals {
  function_name = "${var.name_prefix}-preprocess"
}

resource "aws_cloudwatch_log_group" "preprocess" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "preprocess" {
  function_name = local.function_name
  description   = "Validate Kinesis JSON records, archive message bodies to S3, and forward to SQS"
  role          = aws_iam_role.preprocess.arn
  package_type  = "Image"
  image_uri     = var.image_uri
  architectures = ["arm64"]
  timeout       = 30
  memory_size   = 128

  lifecycle {
    precondition {
      condition     = var.image_uri != null
      error_message = "ECR을 먼저 생성하고 Java 이미지를 업로드한 뒤 processing_image_uri를 설정하세요. scripts/publish-processing-image.sh 안내를 확인하세요."
    }
    precondition {
      condition     = var.image_uri == null ? true : startswith(var.image_uri, "${aws_ecr_repository.preprocess.repository_url}@sha256:")
      error_message = "Lambda 이미지는 Terraform이 관리하는 전처리 ECR 저장소의 digest URI여야 합니다."
    }
  }

  environment {
    variables = {
      QUEUE_URL         = aws_sqs_queue.ingestion.url
      MAX_MESSAGE_BYTES = tostring(aws_sqs_queue.ingestion.max_message_size)
      PROCESSED_BUCKET  = aws_s3_bucket.processed.id
    }
  }

  depends_on = [
    time_sleep.preprocess_iam_propagation,
    aws_ecr_repository_policy.preprocess,
    aws_s3_bucket_public_access_block.processed,
    aws_s3_bucket_server_side_encryption_configuration.processed,
    aws_s3_bucket_versioning.processed,
    aws_s3_bucket_policy.processed_https_only
  ]
}

resource "aws_lambda_event_source_mapping" "telemetry" {
  event_source_arn                   = var.stream_arn
  function_name                      = aws_lambda_function.preprocess.arn
  enabled                            = var.consumer_enabled
  starting_position                  = "TRIM_HORIZON"
  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = 1
  parallelization_factor             = 1
  function_response_types            = ["ReportBatchItemFailures"]
  bisect_batch_on_function_error     = true
  maximum_retry_attempts             = 3
  maximum_record_age_in_seconds      = 86400

  # SQS 실패 목적지는 메타데이터만 보관하므로 전체 실패 이벤트를 S3에 남깁니다.
  destination_config {
    on_failure {
      destination_arn = var.failure_bucket_arn
    }
  }
}
