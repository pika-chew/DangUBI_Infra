output "dashboard_name" {
  description = "CloudWatch 대시보드 이름"
  value       = aws_cloudwatch_dashboard.pipeline.dashboard_name
}

output "alarm_names" {
  description = "파이프라인 알람 이름"
  value       = [for alarm in aws_cloudwatch_metric_alarm.pipeline : alarm.alarm_name]
}

output "alarm_topic_arn" {
  description = "콘솔 Slack 채널 설정에서 구독할 알람 SNS 토픽 ARN"
  value       = aws_sns_topic.alarms.arn
}

output "chatbot_role_arn" {
  description = "콘솔 Slack 채널 설정에서 선택할 IAM 역할 ARN"
  value       = aws_iam_role.chatbot.arn
}
