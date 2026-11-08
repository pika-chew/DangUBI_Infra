locals {
  function_name = "${var.name_prefix}-preprocess"
}

resource "aws_cloudwatch_log_group" "preprocess" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "preprocess" {
  function_name = local.function_name
  description   = "Preprocess IoT telemetry and deliver records to Firehose"
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
      FIREHOSE_STREAM_NAME = var.delivery_destinations["service"].firehose_name
    }
  }

  depends_on = [
    time_sleep.preprocess_iam_propagation,
    aws_ecr_repository_policy.preprocess,
  ]
}

