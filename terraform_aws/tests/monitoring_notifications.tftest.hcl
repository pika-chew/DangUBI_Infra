# CloudWatch 알람 → SNS → Slack(Chatbot) 연결을 모의 provider로 확인합니다.
# Slack ID는 실제 값이 아닌 형식만 맞춘 가짜 값입니다.
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
  slack_channel_id                     = "C0ABCDEF12"
}

run "alarms_publish_to_topic_without_slack" {
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

  assert {
    condition     = length(aws_chatbot_slack_channel_configuration.alarms) == 0 && length(aws_iam_role.chatbot) == 0
    error_message = "워크스페이스 ID가 없으면 Chatbot 리소스를 만들지 않아야 합니다."
  }
}

run "slack_channel_subscribes_alarm_topic" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  variables {
    slack_workspace_id = "T0ABCDEF12"
  }

  assert {
    condition = (
      aws_chatbot_slack_channel_configuration.alarms[0].region == "us-east-2" &&
      aws_chatbot_slack_channel_configuration.alarms[0].slack_channel_id == "C0ABCDEF12" &&
      aws_chatbot_slack_channel_configuration.alarms[0].sns_topic_arns == toset([aws_sns_topic.alarms.arn]) &&
      aws_chatbot_slack_channel_configuration.alarms[0].guardrail_policy_arns == tolist(["arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"])
    )
    error_message = "Chatbot은 us-east-2에서 알람 토픽을 구독하고 읽기 전용 guardrail을 써야 합니다."
  }
}

run "reject_channel_name_as_id" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  variables {
    slack_workspace_id = "C0ABCDEF12"
    slack_channel_id   = "#aws-monitoring"
  }

  expect_failures = [var.slack_workspace_id, var.slack_channel_id]
}
