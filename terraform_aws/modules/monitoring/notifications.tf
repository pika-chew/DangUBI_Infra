locals {
  # Chatbot API는 서울 리전 엔드포인트가 없습니다. 채널 설정은 계정 단위이며 서울 SNS 토픽을 그대로 구독합니다.
  chatbot_region  = "us-east-2"
  chatbot_enabled = var.slack_workspace_id != null && var.slack_channel_id != null
}

# CloudWatch 알람·복구 알림을 받는 토픽입니다.
# AWS 관리형 키(alias/aws/sns)로 암호화하면 CloudWatch가 게시하지 못하므로 SSE를 두지 않습니다.
resource "aws_sns_topic" "alarms" {
  name = "${var.name_prefix}-alarms"
}

resource "aws_iam_role" "chatbot" {
  count = local.chatbot_enabled ? 1 : 0

  name = "${var.name_prefix}-chatbot"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "chatbot.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# 알람 메시지의 그래프를 그리는 데 필요한 읽기 권한만 줍니다.
resource "aws_iam_role_policy_attachment" "chatbot" {
  count = local.chatbot_enabled ? 1 : 0

  role       = aws_iam_role.chatbot[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "aws_chatbot_slack_channel_configuration" "alarms" {
  count = local.chatbot_enabled ? 1 : 0

  region             = local.chatbot_region
  configuration_name = "${var.name_prefix}-aws-monitoring"
  iam_role_arn       = aws_iam_role.chatbot[0].arn
  slack_team_id      = var.slack_workspace_id
  slack_channel_id   = var.slack_channel_id
  sns_topic_arns     = [aws_sns_topic.alarms.arn]
  logging_level      = "ERROR"

  # 기본 guardrail은 AdministratorAccess입니다. Slack에서 실행할 수 있는 명령을 읽기 전용으로 제한합니다.
  guardrail_policy_arns = ["arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"]
}
