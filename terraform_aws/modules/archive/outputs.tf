output "bucket_name" {
  description = "원본 보관용 S3 버킷 이름"
  value       = aws_s3_bucket.raw.id
}

output "bucket_arn" {
  description = "과거 원본과 서비스 Lambda 실패 이벤트를 보관하는 버킷 ARN"
  value       = aws_s3_bucket.raw.arn
}

