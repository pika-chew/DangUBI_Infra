resource "aws_iam_role" "iot_rule" {
  name = "${var.name_prefix}-iot-kinesis"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "iot.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.aws_account_id }
        ArnLike      = { "aws:SourceArn" = local.iot_rule_arn }
      }
    }]
  })
}

resource "aws_iam_role_policy" "iot_rule" {
  name = "${var.name_prefix}-iot-kinesis"
  role = aws_iam_role.iot_rule.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteVehicleRecords"
        Effect   = "Allow"
        Action   = ["kinesis:PutRecord"]
        Resource = aws_kinesis_stream.telemetry.arn
      },
      {
        Sid      = "EncryptSourceRecords"
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey"]
        Resource = aws_kms_key.telemetry.arn
        Condition = {
          StringEquals = {
            "kms:ViaService"                        = "kinesis.${var.aws_region}.amazonaws.com"
            "kms:EncryptionContext:aws:kinesis:arn" = aws_kinesis_stream.telemetry.arn
          }
        }
      },
      {
        Sid    = "WriteRuleErrors"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream",
          "logs:DescribeLogStreams", "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.iot_errors.arn,
          "${aws_cloudwatch_log_group.iot_errors.arn}:*"
        ]
      }
    ]
  })
}

resource "time_sleep" "iot_iam_propagation" {
  create_duration = "30s"

  triggers = {
    role_arn          = aws_iam_role.iot_rule.arn
    trust_policy_hash = sha256(aws_iam_role.iot_rule.assume_role_policy)
    role_policy_hash  = sha256(aws_iam_role_policy.iot_rule.policy)
  }
}
