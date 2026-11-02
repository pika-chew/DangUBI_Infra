output "dashboard_name" {
  description = "CloudWatch 대시보드 이름"
  value       = aws_cloudwatch_dashboard.pipeline.dashboard_name
}

output "alarm_names" {
  description = "파이프라인 알람 이름"
  value       = [for alarm in aws_cloudwatch_metric_alarm.pipeline : alarm.alarm_name]
}
