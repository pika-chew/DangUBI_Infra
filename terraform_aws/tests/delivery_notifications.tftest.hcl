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
    condition     = length(aws_s3_bucket_notification.processed) == 0 && toset(keys(aws_sqs_queue_policy.s3_notifications)) == toset(["service"])
    error_message = "기본 설정에서는 서비스 큐의 수신 권한만 준비해야 합니다."
  }

  assert {
    condition = (
      jsondecode(aws_sqs_queue_policy.s3_notifications["service"].policy).Statement[0].Condition.ArnEquals["aws:SourceArn"] == aws_s3_bucket.processed.arn &&
      jsondecode(aws_sqs_queue_policy.s3_notifications["service"].policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == var.aws_account_id
    )
    error_message = "서비스 큐는 기존 가공 버킷과 해당 계정에서 오는 알림만 허용해야 합니다."
  }
}

run "ci_firehose_reuses_processed_bucket" {
  command = apply

  module {
    source = "./modules/delivery"
  }

  assert {
    condition     = one(aws_kinesis_firehose_delivery_stream.processed["ci"].extended_s3_configuration).bucket_arn == aws_s3_bucket.processed.arn
    error_message = "CI Firehose는 기존 가공 버킷을 재사용해야 합니다."
  }
}

run "notify_only_service_processed_objects" {
  command = apply

  module {
    source = "./modules/delivery"
  }

  variables {
    s3_queue_notifications_enabled = true
  }

  assert {
    condition = (
      toset(keys(aws_s3_bucket_notification.processed)) == toset(["service"]) &&
      aws_s3_bucket_notification.processed["service"].bucket == aws_s3_bucket.processed.id &&
      one(aws_s3_bucket_notification.processed["service"].queue).queue_arn == aws_sqs_queue.ingestion.arn
    )
    error_message = "서비스 알림만 기존 가공 버킷과 서비스 큐를 연결해야 합니다."
  }

  assert {
    condition = alltrue([
      for notification in aws_s3_bucket_notification.processed :
      startswith(one(aws_kinesis_firehose_delivery_stream.processed["service"].extended_s3_configuration).prefix, one(notification.queue).filter_prefix) &&
      !startswith(one(aws_kinesis_firehose_delivery_stream.processed["ci"].extended_s3_configuration).prefix, one(notification.queue).filter_prefix) &&
      !startswith(one(aws_kinesis_firehose_delivery_stream.processed["ci"].extended_s3_configuration).error_output_prefix, one(notification.queue).filter_prefix) &&
      !startswith("processed/legacy.json", one(notification.queue).filter_prefix) &&
      !startswith("firehose-errors/example.json", one(notification.queue).filter_prefix) &&
      !startswith("aws/lambda/async/example", one(notification.queue).filter_prefix)
    ])
    error_message = "서비스 정상 가공 경로만 알리고 CI와 오류·실패 보관 파일은 제외해야 합니다."
  }
}
