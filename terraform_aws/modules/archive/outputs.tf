output "bucket_name" {
  description = "원본 보관용 S3 버킷 이름"
  value       = aws_s3_bucket.raw.id
}

output "bucket_arn" {
  description = "S3 직접 전달 대상 버킷 ARN"
  value       = aws_s3_bucket.raw.arn
}

output "channel_name" {
  description = "Kinesis S3 전달 Channel 이름"
  value       = awscc_kinesis_channel.raw.channel_name
}

output "channel_id" {
  description = "CloudWatch 전달 지표의 필수 dimension인 Channel ID"
  value       = awscc_kinesis_channel.raw.channel_id
}

output "channel_arn" {
  description = "Kinesis S3 전달 Channel ARN"
  value       = awscc_kinesis_channel.raw.channel_arn
}

output "delivery_log_group_name" {
  description = "Kinesis S3 직접 전달 로그 그룹"
  value       = aws_cloudwatch_log_group.delivery.name
}

output "delivery_role_arn" {
  description = "Kinesis가 S3 전달에 사용하는 실행 역할"
  value       = aws_iam_role.delivery.arn
}
