output "state_bucket_name" {
  description = "서비스와 bootstrap state를 별도 경로에 저장하는 전용 S3 버킷"
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "state 접근 정책에 사용할 버킷 ARN"
  value       = aws_s3_bucket.state.arn
}
