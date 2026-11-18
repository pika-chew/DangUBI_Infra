# IoT Core 자체 로그(연결 실패, 인증서·정책 거부)를 AWSIotLogsV2에 남깁니다.
# IoT가 로그 그룹을 직접 만들면 보관 기간이 무기한이므로 미리 만들어 둡니다.
resource "aws_cloudwatch_log_group" "iot_core" {
  name              = "AWSIotLogsV2"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "iot_logging" {
  name = "${var.name_prefix}-iot-logging"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "iot.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.aws_account_id }
      }
    }]
  })
}

resource "aws_iam_role_policy" "iot_logging" {
  name = "${var.name_prefix}-iot-logging"
  role = aws_iam_role.iot_logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "WriteIotCoreLogs"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup", "logs:CreateLogStream",
        "logs:DescribeLogStreams", "logs:PutLogEvents"
      ]
      Resource = [
        aws_cloudwatch_log_group.iot_core.arn,
        "${aws_cloudwatch_log_group.iot_core.arn}:*"
      ]
    }]
  })
}

# SetV2LoggingOptions는 역할을 바로 검증하므로 IAM 전파를 기다립니다.
resource "time_sleep" "iot_logging_iam_propagation" {
  create_duration = "30s"

  triggers = {
    role_arn          = aws_iam_role.iot_logging.arn
    trust_policy_hash = sha256(aws_iam_role.iot_logging.assume_role_policy)
    role_policy_hash  = sha256(aws_iam_role_policy.iot_logging.policy)
  }
}

# 계정·리전 단위 단일 설정입니다. INFO/DEBUG는 메시지마다 로그가 생겨 비용이 커지므로 ERROR로 둡니다.
resource "aws_iot_logging_options" "this" {
  default_log_level = "ERROR"
  disable_all_logs  = false
  role_arn          = time_sleep.iot_logging_iam_propagation.triggers["role_arn"]

  depends_on = [aws_cloudwatch_log_group.iot_core]
}
