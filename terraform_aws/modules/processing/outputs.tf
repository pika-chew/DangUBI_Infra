output "repository_url" {
  description = "백엔드/CI가 Java Lambda 이미지를 업로드할 ECR 주소"
  value       = aws_ecr_repository.preprocess.repository_url
}

output "repository_name" {
  description = "Java Lambda ECR 저장소 이름"
  value       = aws_ecr_repository.preprocess.name
}

output "function_name" {
  description = "Kinesis → SQS 처리 Lambda 이름"
  value       = aws_lambda_function.preprocess.function_name
}

output "function_arn" {
  description = "전처리 Lambda ARN"
  value       = aws_lambda_function.preprocess.arn
}

output "event_source_mapping_id" {
  description = "Kinesis 이벤트 소스 매핑 UUID"
  value       = aws_lambda_event_source_mapping.telemetry.uuid
}

output "function_log_group_name" {
  description = "전처리 Lambda 로그 그룹"
  value       = aws_cloudwatch_log_group.preprocess.name
}

output "ci_function_name" {
  description = "Jenkins가 후보 이미지를 배포하고 직접 호출할 CI Lambda 이름"
  value       = aws_lambda_function.preprocess_ci.function_name
}

output "ci_function_arn" {
  description = "Jenkins의 CI Lambda 권한 범위를 제한할 함수 ARN"
  value       = aws_lambda_function.preprocess_ci.arn
}

output "ci_function_log_group_name" {
  description = "CI Lambda 로그 그룹"
  value       = aws_cloudwatch_log_group.preprocess_ci.name
}
