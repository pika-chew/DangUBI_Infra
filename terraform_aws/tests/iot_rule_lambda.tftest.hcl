# Lambda 직접 호출 규칙을 모의 provider로 확인하며 실제 AWS나 단말을 사용하지 않습니다.
mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
}

mock_provider "time" {}

variables {
  name_prefix         = "ubi-dev"
  aws_region          = "ap-northeast-2"
  aws_account_id      = "123456789012"
  device_csrs         = {}
  topic_prefix        = "ubi/dev/vehicles"
  log_retention_days  = 7
  rule_enabled        = true
  lambda_function_arn = "arn:aws:lambda:ap-northeast-2:123456789012:function:ubi-dev-preprocess"
}

run "invoke_service_lambda_only" {
  command = plan

  module {
    source = "./modules/ingestion"
  }

  assert {
    condition = (
      length(aws_iot_topic_rule.telemetry.kinesis) == 0 &&
      length(aws_iot_topic_rule.telemetry.lambda) == 1 &&
      one(aws_iot_topic_rule.telemetry.lambda).function_arn == var.lambda_function_arn
    )
    error_message = "IoT Rule의 전송 대상은 항상 지정한 서비스 Lambda여야 합니다."
  }
}

run "disabled_rule_keeps_lambda_target" {
  command = plan

  module {
    source = "./modules/ingestion"
  }

  variables {
    rule_enabled = false
  }

  assert {
    condition = (
      !aws_iot_topic_rule.telemetry.enabled &&
      length(aws_iot_topic_rule.telemetry.kinesis) == 0 &&
      one(aws_iot_topic_rule.telemetry.lambda).function_arn == var.lambda_function_arn
    )
    error_message = "규칙을 꺼도 전송 대상은 Lambda로 고정되어야 합니다."
  }
}

run "reject_lambda_in_another_region" {
  command = plan

  module {
    source = "./modules/ingestion"
  }

  variables {
    lambda_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:ubi-dev-preprocess"
  }

  expect_failures = [var.lambda_function_arn]
}

run "reject_lambda_in_another_account" {
  command = plan

  module {
    source = "./modules/ingestion"
  }

  variables {
    lambda_function_arn = "arn:aws:lambda:ap-northeast-2:999999999999:function:ubi-dev-preprocess"
  }

  expect_failures = [var.lambda_function_arn]
}
