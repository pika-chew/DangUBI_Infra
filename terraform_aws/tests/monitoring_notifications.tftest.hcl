# CloudWatch 알람 → SNS 연결과 콘솔 Slack 채널 설정이 쓸 역할을 모의 provider로 확인합니다.
mock_provider "aws" {
  mock_resource "aws_sns_topic" {
    override_during = plan
    defaults = {
      arn = "arn:aws:sns:ap-northeast-2:123456789012:ubi-dev-alarms"
    }
  }
}

variables {
  name_prefix                          = "ubi-dev"
  aws_region                           = "ap-northeast-2"
  queue_name                           = "ubi-dev-ingestion"
  dlq_name                             = "ubi-dev-ingestion-dlq"
  queue_age_threshold_seconds          = 300
  processing_function_name             = "ubi-dev-preprocess"
  processing_log_group_name            = "/aws/lambda/ubi-dev-preprocess"
  iot_rule_name                        = "ubi_dev_telemetry"
  iot_error_log_group_name             = "/aws/iot/ubi-dev-rule-errors"
  firehose_stream_name                 = "ubi-dev-processed-firehose"
  firehose_log_group_name              = "/aws/kinesisfirehose/ubi-dev"
  firehose_freshness_threshold_seconds = 300
}

run "alarms_publish_to_topic" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  assert {
    condition = alltrue([
      for alarm in aws_cloudwatch_metric_alarm.pipeline :
      contains(alarm.alarm_actions, aws_sns_topic.alarms.arn) && contains(alarm.ok_actions, aws_sns_topic.alarms.arn)
    ])
    error_message = "모든 알람은 알람·복구 시 알람 SNS 토픽으로 게시해야 합니다."
  }
}

run "chatbot_role_is_read_only" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.chatbot.assume_role_policy).Statement[0].Principal.Service == "chatbot.amazonaws.com" &&
      alltrue([
        for action in jsondecode(aws_iam_role_policy.chatbot.policy).Statement[0].Action :
        startswith(action, "cloudwatch:Get") || startswith(action, "cloudwatch:List")
      ])
    )
    error_message = "Chatbot 역할은 chatbot.amazonaws.com만 맡고 CloudWatch 읽기 권한만 가져야 합니다."
  }
}
