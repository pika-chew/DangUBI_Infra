# All providers are mocked; these tests never deploy AWS resources.
mock_provider "aws" {
  mock_resource "aws_ecr_repository" {
    defaults = {
      repository_url = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/ubi-dev-preprocess"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-processing"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:ap-northeast-2:123456789012:log-group:/aws/lambda/mock-processing"
    }
  }

  mock_resource "aws_sqs_queue" {
    defaults = {
      arn = "arn:aws:sqs:ap-northeast-2:123456789012:ubi-dev-ingestion"
      url = "https://sqs.ap-northeast-2.amazonaws.com/123456789012/ubi-dev-ingestion"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      id  = "ubi-dev-processed-123456789012-ap-northeast-2"
      arn = "arn:aws:s3:::ubi-dev-processed-123456789012-ap-northeast-2"
    }
  }
}

mock_provider "time" {}

override_resource {
  target = aws_cloudwatch_log_group.preprocess_ci
  values = {
    arn = "arn:aws:logs:ap-northeast-2:123456789012:log-group:/aws/lambda/ubi-dev-preprocess-ci"
  }
}

override_resource {
  target = aws_sqs_queue.ingestion_ci
  values = {
    arn = "arn:aws:sqs:ap-northeast-2:123456789012:ubi-dev-ingestion-ci"
    url = "https://sqs.ap-northeast-2.amazonaws.com/123456789012/ubi-dev-ingestion-ci"
  }
}

override_resource {
  target = aws_s3_bucket.processed_ci
  values = {
    id  = "ubi-dev-processed-ci-123456789012-ap-northeast-2"
    arn = "arn:aws:s3:::ubi-dev-processed-ci-123456789012-ap-northeast-2"
  }
}

variables {
  image_uri                  = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/ubi-dev-preprocess@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  name_prefix                = "ubi-dev"
  visibility_timeout_seconds = 120
  stream_arn                 = "arn:aws:kinesis:ap-northeast-2:123456789012:stream/ubi-dev-telemetry"
  stream_kms_key_arn         = "arn:aws:kms:ap-northeast-2:123456789012:key/11111111-1111-1111-1111-111111111111"
  failure_bucket_arn         = "arn:aws:s3:::ubi-dev-failures"
  aws_region                 = "ap-northeast-2"
  aws_account_id             = "123456789012"
  log_retention_days         = 7
  batch_size                 = 100
  consumer_enabled           = true
}

run "bootstrap_and_isolate_ci" {
  command = apply

  module {
    source = "./modules/processing"
  }

  assert {
    condition     = aws_lambda_function.preprocess_ci.image_uri == var.image_uri && aws_lambda_function.preprocess.image_uri == var.image_uri
    error_message = "Both functions must bootstrap from the approved image."
  }

  assert {
    condition = (
      aws_lambda_function.preprocess_ci.environment[0].variables.QUEUE_URL != aws_lambda_function.preprocess.environment[0].variables.QUEUE_URL &&
      aws_lambda_function.preprocess_ci.environment[0].variables.PROCESSED_BUCKET != aws_lambda_function.preprocess.environment[0].variables.PROCESSED_BUCKET
    )
    error_message = "CI must write to separate SQS and S3 resources."
  }

  assert {
    condition     = aws_lambda_event_source_mapping.telemetry.function_name == aws_lambda_function.preprocess.arn
    error_message = "The source stream must continue invoking the service function."
  }

  assert {
    condition     = aws_lambda_function.preprocess_ci.role == aws_lambda_function.preprocess.role
    error_message = "CI must reuse the service function's execution role."
  }

  assert {
    condition = toset(flatten([
      for statement in jsondecode(aws_iam_role_policy.preprocess.policy).Statement : statement.Resource
      if contains(["SendToIngestionQueue", "ArchiveProcessedMessages", "WriteFunctionLogs"], statement.Sid)
      ])) == toset([
      aws_sqs_queue.ingestion.arn,
      aws_sqs_queue.ingestion_ci.arn,
      "${aws_s3_bucket.processed.arn}/processed/*",
      "${aws_s3_bucket.processed_ci.arn}/processed/*",
      aws_cloudwatch_log_group.preprocess.arn,
      "${aws_cloudwatch_log_group.preprocess.arn}:*",
      aws_cloudwatch_log_group.preprocess_ci.arn,
      "${aws_cloudwatch_log_group.preprocess_ci.arn}:*"
    ])
    error_message = "The shared role must retain service access and also allow the test queue, bucket, and logs."
  }

  assert {
    condition = toset(jsondecode(aws_ecr_repository_policy.preprocess.policy).Statement[0].Condition.ArnLike["aws:SourceArn"]) == toset([
      "arn:aws:lambda:ap-northeast-2:123456789012:function:ubi-dev-preprocess",
      "arn:aws:lambda:ap-northeast-2:123456789012:function:ubi-dev-preprocess-ci"
    ])
    error_message = "ECR image retrieval must allow exactly the service and CI functions."
  }
}

run "promotion_only_updates_service_image" {
  command = plan

  module {
    source = "./modules/processing"
  }

  variables {
    image_uri          = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/ubi-dev-preprocess@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    log_retention_days = 14
  }

  assert {
    condition     = aws_lambda_function.preprocess.image_uri == var.image_uri
    error_message = "The service function must follow the promoted image digest."
  }

  assert {
    condition     = aws_lambda_function.preprocess_ci.image_uri == "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/ubi-dev-preprocess@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    error_message = "Changing the approved digest must not overwrite the existing CI image."
  }

  assert {
    condition     = aws_cloudwatch_log_group.preprocess_ci.retention_in_days == 14
    error_message = "Terraform must still manage CI infrastructure settings other than the image."
  }
}

run "reject_foreign_bootstrap_repository" {
  command = plan

  module {
    source = "./modules/processing"
  }

  variables {
    image_uri = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/unrelated@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  }

  expect_failures = [
    aws_lambda_function.preprocess,
    aws_lambda_function.preprocess_ci
  ]
}
