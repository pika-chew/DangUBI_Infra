locals {
  ci_function_name = "${var.name_prefix}-preprocess-ci"
}

resource "aws_cloudwatch_log_group" "preprocess_ci" {
  name              = "/aws/lambda/${local.ci_function_name}"
  retention_in_days = var.log_retention_days
}

# Jenkins가 직접 호출하고 CI 전용 Firehose로 결과를 전달합니다.
resource "aws_lambda_function" "preprocess_ci" {
  function_name = local.ci_function_name
  description   = "CI validation of candidate processing images through a dedicated Firehose stream"
  role          = aws_iam_role.preprocess.arn
  package_type  = "Image"
  image_uri     = var.image_uri
  architectures = ["arm64"]
  timeout       = 30
  memory_size   = 128

  lifecycle {
    # 최초 생성에는 승인된 이미지를 쓰고, 이후 이미지 갱신은 Jenkins가 담당합니다.
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
      FIREHOSE_STREAM_NAME = var.delivery_destinations["ci"].firehose_name
    }
  }

  depends_on = [
    time_sleep.preprocess_iam_propagation,
    aws_ecr_repository_policy.preprocess,
  ]
}
