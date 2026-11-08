locals {
  ci_function_name = "${var.name_prefix}-preprocess-ci"
}

resource "aws_cloudwatch_log_group" "preprocess_ci" {
  name              = "/aws/lambda/${local.ci_function_name}"
  retention_in_days = var.log_retention_days
}

# Jenkins invokes this function directly; it must not consume the source stream.
resource "aws_lambda_function" "preprocess_ci" {
  function_name = local.ci_function_name
  description   = "CI validation of candidate processing images against isolated S3 and SQS resources"
  role          = aws_iam_role.preprocess.arn
  package_type  = "Image"
  image_uri     = var.image_uri
  architectures = ["arm64"]
  timeout       = 30
  memory_size   = 128

  lifecycle {
    # Bootstrap from the approved image; Jenkins owns subsequent image updates.
    ignore_changes = [image_uri]

    precondition {
      condition     = var.image_uri != null
      error_message = "CI Lambda 최초 생성에는 processing_image_uri에 기존 검증된 이미지 digest가 필요합니다."
    }
    precondition {
      condition     = var.image_uri == null ? true : startswith(var.image_uri, "${aws_ecr_repository.preprocess.repository_url}@sha256:")
      error_message = "CI Lambda 초기 이미지는 전처리 ECR 저장소의 digest URI여야 합니다."
    }
  }

  environment {
    variables = {
      QUEUE_URL         = aws_sqs_queue.ingestion_ci.url
      MAX_MESSAGE_BYTES = tostring(aws_sqs_queue.ingestion_ci.max_message_size)
      PROCESSED_BUCKET  = aws_s3_bucket.processed_ci.id
    }
  }

  depends_on = [
    time_sleep.preprocess_iam_propagation,
    aws_ecr_repository_policy.preprocess,
    aws_s3_bucket_public_access_block.processed_ci,
    aws_s3_bucket_server_side_encryption_configuration.processed_ci,
    aws_s3_bucket_policy.processed_ci_https_only
  ]
}
