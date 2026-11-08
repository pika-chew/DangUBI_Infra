resource "aws_iam_role" "preprocess_ci" {
  name = local.ci_function_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "preprocess_ci" {
  name = local.ci_function_name
  role = aws_iam_role.preprocess_ci.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SendToTestQueue"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.ingestion_ci.arn
      },
      {
        Sid       = "ArchiveTestMessages"
        Effect    = "Allow"
        Action    = ["s3:PutObject"]
        Resource  = "${aws_s3_bucket.processed_ci.arn}/processed/*"
        Condition = { StringEquals = { "s3:ResourceAccount" = var.aws_account_id } }
      },
      {
        Sid      = "WriteTestFunctionLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.preprocess_ci.arn}:*"
      }
    ]
  })
}

resource "time_sleep" "preprocess_ci_iam_propagation" {
  create_duration = "30s"

  triggers = {
    role_arn          = aws_iam_role.preprocess_ci.arn
    trust_policy_hash = sha256(aws_iam_role.preprocess_ci.assume_role_policy)
    role_policy_hash  = sha256(aws_iam_role_policy.preprocess_ci.policy)
  }
}
