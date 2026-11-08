resource "aws_iam_role" "preprocess" {
  name = "${var.name_prefix}-preprocess"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# 서비스·CI 함수가 이 역할과 각 환경의 리소스 접근 권한을 공유합니다.
resource "aws_iam_role_policy" "preprocess" {
  name = "${var.name_prefix}-preprocess"
  role = aws_iam_role.preprocess.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSourceStream"
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream", "kinesis:DescribeStreamSummary",
          "kinesis:GetRecords", "kinesis:GetShardIterator", "kinesis:ListShards"
        ]
        Resource = var.stream_arn
      },
      {
        Sid      = "DecryptSourceRecords"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.stream_kms_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService"                        = "kinesis.${var.aws_region}.amazonaws.com"
            "kms:EncryptionContext:aws:kinesis:arn" = var.stream_arn
          }
        }
      },
      {
        Sid    = "WriteProcessedRecordsToFirehose"
        Effect = "Allow"
        Action = ["firehose:PutRecord", "firehose:PutRecordBatch"]
        Resource = [
          var.delivery_destinations["service"].firehose_arn,
          var.delivery_destinations["ci"].firehose_arn
        ]
      },
      {
        Sid    = "SendToIngestionQueue"
        Effect = "Allow"
        Action = ["sqs:SendMessage"] # SendMessageBatch에도 동일한 IAM 작업을 사용합니다.
        Resource = [
          var.delivery_destinations["service"].queue_arn,
          var.delivery_destinations["ci"].queue_arn
        ]
      },
      {
        Sid    = "ArchiveProcessedMessages"
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = [
          "${var.delivery_destinations["service"].bucket_arn}/processed/*",
          "${var.delivery_destinations["ci"].bucket_arn}/processed/*"
        ]
        Condition = { StringEquals = { "s3:ResourceAccount" = var.aws_account_id } }
      },
      {
        Sid    = "WriteFunctionLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream",
          "logs:DescribeLogStreams", "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.preprocess.arn,
          "${aws_cloudwatch_log_group.preprocess.arn}:*",
          aws_cloudwatch_log_group.preprocess_ci.arn,
          "${aws_cloudwatch_log_group.preprocess_ci.arn}:*"
        ]
      },
      {
        Sid       = "InspectFailureDestination"
        Effect    = "Allow"
        Action    = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource  = [var.failure_bucket_arn, var.delivery_destinations["ci"].bucket_arn]
        Condition = { StringEquals = { "s3:ResourceAccount" = var.aws_account_id } }
      },
      {
        Sid    = "RetainFailedInvocations"
        Effect = "Allow"
        Action = ["s3:PutObject"]
        # Lambda 실패 목적지의 공식 권한 예제에 맞춰 지정 버킷의 객체 범위를 허용합니다.
        # 실제 실패 이벤트 저장 경로는 Lambda가 aws/lambda/ 아래로 정합니다.
        Resource = [
          "${var.failure_bucket_arn}/*",
          "${var.delivery_destinations["ci"].bucket_arn}/*"
        ]
        Condition = { StringEquals = { "s3:ResourceAccount" = var.aws_account_id } }
      }
    ]
  })
}

resource "time_sleep" "preprocess_iam_propagation" {
  create_duration = "30s"

  triggers = {
    role_arn          = aws_iam_role.preprocess.arn
    trust_policy_hash = sha256(aws_iam_role.preprocess.assume_role_policy)
    role_policy_hash  = sha256(aws_iam_role_policy.preprocess.policy)
  }
}
