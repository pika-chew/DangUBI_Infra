# 모든 provider를 모의 객체로 대체하므로 AWS 리소스나 메시지를 생성하지 않습니다.
mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-delivery"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      id  = "ubi-dev-processed-123456789012-ap-northeast-2"
      arn = "arn:aws:s3:::ubi-dev-processed-123456789012-ap-northeast-2"
    }
  }

  mock_resource "aws_sqs_queue" {
    defaults = {
      arn = "arn:aws:sqs:ap-northeast-2:123456789012:ubi-dev-ingestion"
      url = "https://sqs.ap-northeast-2.amazonaws.com/123456789012/ubi-dev-ingestion"
    }
  }
}

mock_provider "time" {}

override_resource {
  target = aws_s3_bucket.processed_ci
  values = {
    id  = "ubi-dev-processed-ci-123456789012-ap-northeast-2"
    arn = "arn:aws:s3:::ubi-dev-processed-ci-123456789012-ap-northeast-2"
  }
}

override_resource {
  target = aws_sqs_queue.ingestion_ci
  values = {
    arn = "arn:aws:sqs:ap-northeast-2:123456789012:ubi-dev-ingestion-ci"
    url = "https://sqs.ap-northeast-2.amazonaws.com/123456789012/ubi-dev-ingestion-ci"
  }
}

variables {
  name_prefix                = "ubi-dev"
  aws_account_id             = "123456789012"
  aws_region                 = "ap-northeast-2"
  log_retention_days         = 7
  visibility_timeout_seconds = 120
}

run "notifications_stay_off_by_default" {
  command = apply

  module {
    source = "./modules/delivery"
  }

  assert {
    condition     = length(aws_s3_bucket_notification.processed) == 0 && length(aws_sqs_queue_policy.s3_notifications) == 2
    error_message = "기본 설정에서는 수신 권한만 준비하고 서비스·CI 알림은 생성하지 않아야 합니다."
  }

  assert {
    condition = (
      jsondecode(aws_sqs_queue_policy.s3_notifications["service"].policy).Statement[0].Condition.ArnEquals["aws:SourceArn"] == aws_s3_bucket.processed.arn &&
      jsondecode(aws_sqs_queue_policy.s3_notifications["ci"].policy).Statement[0].Condition.ArnEquals["aws:SourceArn"] == aws_s3_bucket.processed_ci.arn &&
      alltrue([
        for policy in aws_sqs_queue_policy.s3_notifications :
        jsondecode(policy.policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == var.aws_account_id
      ])
    )
    error_message = "각 큐는 해당 환경의 버킷과 계정에서 오는 알림만 허용해야 합니다."
  }
}

run "enable_ci_without_service_notifications" {
  command = apply

  module {
    source = "./modules/delivery"
  }

  variables {
    ci_s3_queue_notifications_enabled = true
  }

  assert {
    condition     = toset(keys(aws_s3_bucket_notification.processed)) == toset(["ci"])
    error_message = "CI 알림만 켜도 서비스 알림이 함께 생성되어서는 안 됩니다."
  }

  assert {
    condition = (
      aws_s3_bucket_notification.processed["ci"].bucket == aws_s3_bucket.processed_ci.id &&
      one(aws_s3_bucket_notification.processed["ci"].queue).queue_arn == aws_sqs_queue.ingestion_ci.arn
    )
    error_message = "CI 버킷의 알림은 CI 큐로 연결되어야 합니다."
  }
}

run "enable_both_with_processed_objects_only" {
  command = apply

  module {
    source = "./modules/delivery"
  }

  variables {
    s3_queue_notifications_enabled    = true
    ci_s3_queue_notifications_enabled = true
  }

  assert {
    condition = (
      length(aws_s3_bucket_notification.processed) == 2 &&
      aws_s3_bucket_notification.processed["service"].bucket == aws_s3_bucket.processed.id &&
      one(aws_s3_bucket_notification.processed["service"].queue).queue_arn == aws_sqs_queue.ingestion.arn
    )
    error_message = "서비스·CI를 모두 켜면 서비스 버킷은 서비스 큐에 연결되어야 합니다."
  }

  assert {
    condition = alltrue([
      for notification in aws_s3_bucket_notification.processed :
      startswith(local.firehose_data_prefix, one(notification.queue).filter_prefix) &&
      !startswith("processed/legacy.json", one(notification.queue).filter_prefix) &&
      !startswith("firehose-errors/example.json", one(notification.queue).filter_prefix) &&
      !startswith("aws/lambda/async/example", one(notification.queue).filter_prefix)
    ])
    error_message = "새 정상 가공 경로만 알리고 기존 직접 저장 파일과 오류·실패 보관 파일은 제외해야 합니다."
  }
}
