resource "aws_iam_role" "firehose" {
  for_each = local.firehose_destinations

  name = "${each.value.stream_name}-delivery"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "firehose" {
  for_each = local.firehose_destinations

  name = "${each.value.stream_name}-delivery"
  role = aws_iam_role.firehose[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InspectDestinationBucket"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"]
        Resource = aws_s3_bucket.processed.arn
      },
      {
        Sid    = "DeliverProcessedRecords"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"
        ]
        Resource = [
          "${aws_s3_bucket.processed.arn}/${each.value.data_prefix}*",
          "${aws_s3_bucket.processed.arn}/${each.value.errors_prefix}*"
        ]
      },
      {
        Sid      = "WriteDeliveryLogs"
        Effect   = "Allow"
        Action   = ["logs:PutLogEvents"]
        Resource = aws_cloudwatch_log_stream.firehose[each.key].arn
      }
    ]
  })
}

resource "time_sleep" "firehose_iam_propagation" {
  for_each = local.firehose_destinations

  create_duration = "30s"

  triggers = {
    role_arn          = aws_iam_role.firehose[each.key].arn
    trust_policy_hash = sha256(aws_iam_role.firehose[each.key].assume_role_policy)
    role_policy_hash  = sha256(aws_iam_role_policy.firehose[each.key].policy)
  }
}
