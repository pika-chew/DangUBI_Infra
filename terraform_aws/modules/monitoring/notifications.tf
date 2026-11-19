# CloudWatch 알람 → SNS → Amazon Q Developer in chat applications(구 AWS Chatbot) → Slack
#
# Slack 채널 설정은 콘솔에서 만듭니다. Terraform(API)으로는 생성 요청이 성공해도 설정이 만들어지지 않았습니다.
# 콘솔에서 아래 토픽과 역할을 선택하고, 가드레일은 CloudWatchReadOnlyAccess로 둡니다.

# CloudWatch 알람·복구 알림을 받는 토픽입니다.
# AWS 관리형 키(alias/aws/sns)로 암호화하면 CloudWatch가 게시하지 못하므로 SSE를 두지 않습니다.
resource "aws_sns_topic" "alarms" {
  name = "${var.name_prefix}-alarms"
}

# 콘솔의 채널 설정에서 "기존 역할 사용"으로 선택하는 역할입니다.
resource "aws_iam_role" "chatbot" {
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

# 알람 메시지에 지표 그래프를 붙이는 데 필요한 읽기 권한만 줍니다.
# 관리형 정책 연결(iam:AttachRolePolicy)은 Terraform CI 사용자에게 없으므로 인라인 정책을 씁니다.
# 아래 작업은 리소스 단위 권한을 지원하지 않아 Resource를 "*"로 둡니다.
resource "aws_iam_role_policy" "chatbot" {
  name = "${var.name_prefix}-chatbot-notifications"
  role = aws_iam_role.chatbot.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "RenderAlarmGraphs"
      Effect = "Allow"
      Action = [
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:GetMetricWidgetImage",
        "cloudwatch:ListMetrics"
      ]
      Resource = "*"
    }]
  })
}
