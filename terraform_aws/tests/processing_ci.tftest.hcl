# 모든 provider를 모의 객체로 대체하므로 실제 AWS 리소스를 배포하지 않습니다.
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


}

mock_provider "time" {}

override_resource {
  target = aws_cloudwatch_log_group.preprocess_ci
  values = {
    arn = "arn:aws:logs:ap-northeast-2:123456789012:log-group:/aws/lambda/ubi-dev-preprocess-ci"
  }
}

variables {
  image_uri          = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/ubi-dev-preprocess@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  name_prefix        = "ubi-dev"
  failure_bucket_arn = "arn:aws:s3:::ubi-dev-failures"
  aws_region         = "ap-northeast-2"
  aws_account_id     = "123456789012"
  log_retention_days = 7
  delivery_destinations = {
    service = {
      bucket_arn    = "arn:aws:s3:::ubi-dev-processed-123456789012-ap-northeast-2"
      firehose_name = "ubi-dev-processed-firehose"
      firehose_arn  = "arn:aws:firehose:ap-northeast-2:123456789012:deliverystream/ubi-dev-processed-firehose"
    }
    ci = {
      bucket_arn    = "arn:aws:s3:::ubi-dev-processed-ci-123456789012-ap-northeast-2"
      firehose_name = "ubi-dev-processed-ci-firehose"
      firehose_arn  = "arn:aws:firehose:ap-northeast-2:123456789012:deliverystream/ubi-dev-processed-ci-firehose"
    }
  }
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
      aws_lambda_function.preprocess_ci.environment[0].variables.FIREHOSE_STREAM_NAME != aws_lambda_function.preprocess.environment[0].variables.FIREHOSE_STREAM_NAME
    )
    error_message = "CI must deliver records to its own Firehose stream."
  }

  assert {
    condition     = aws_lambda_function.preprocess_ci.role == aws_lambda_function.preprocess.role
    error_message = "CI must reuse the service function's execution role."
  }

  assert {
    condition = toset(flatten([
      for statement in jsondecode(aws_iam_role_policy.preprocess.policy).Statement : statement.Resource
      if contains(["WriteProcessedRecordsToFirehose", "WriteFunctionLogs"], statement.Sid)
      ])) == toset([
      var.delivery_destinations["service"].firehose_arn,
      var.delivery_destinations["ci"].firehose_arn,
      aws_cloudwatch_log_group.preprocess.arn,
      "${aws_cloudwatch_log_group.preprocess.arn}:*",
      aws_cloudwatch_log_group.preprocess_ci.arn,
      "${aws_cloudwatch_log_group.preprocess_ci.arn}:*"
    ])
    error_message = "The shared role must allow both Firehose streams and function logs."
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
