data "aws_partition" "current" {}

resource "aws_iam_role" "delivery" {
  name = "${var.name_prefix}-kinesis-s3-delivery"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "kinesis.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.aws_account_id }
        ArnLike = {
          "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:kinesis:${var.aws_region}:${var.aws_account_id}:channel/*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "delivery" {
  name = "${var.name_prefix}-kinesis-s3-delivery"
  role = aws_iam_role.delivery.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ValidateAndDecryptSourceStreamKey"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = var.stream_kms_key_arn
        Condition = {
          StringEqualsIfExists = {
            "kms:ViaService" = "kinesis.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Sid      = "ListDestinationBucket"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"]
        Resource = aws_s3_bucket.raw.arn
      },
      {
        Sid    = "WriteRecordsAndDeliveryErrors"
        Effect = "Allow"
        # S3 multipart 시작·업로드·완료는 IAM의 s3:PutObject 권한으로 허용합니다.
        Action = ["s3:PutObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
        Resource = [
          "${aws_s3_bucket.raw.arn}/raw/*",
          "${aws_s3_bucket.raw.arn}/delivery-errors/*"
        ]
      },
      {
        Sid    = "EnsureDeliveryLogGroup"
        Effect = "Allow"
        # AWS의 직접 전달 샘플에는 대상 로그 스트림의 조회 권한도 포함됩니다.
        Action = ["logs:CreateLogGroup", "logs:DescribeLogStreams"]
        # Terraform의 ARN에는 :*가 없습니다. Kinesis 전달의 로그 권한 예제는
        # :*를 포함하므로 같은 로그 그룹의 두 ARN 형식을 모두 허용합니다.
        Resource = [
          aws_cloudwatch_log_group.delivery.arn,
          "${aws_cloudwatch_log_group.delivery.arn}:*"
        ]
      },
      {
        Sid      = "WriteDeliveryLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.delivery.arn}:*"
      }
    ]
  })
}

# AWSCC의 Channel 생성 전에 IAM 변경 사항이 전파될 시간을 줍니다.
# 역할 또는 권한 내용이 바뀔 때만 다시 대기하며, 매 apply마다 기다리지 않습니다.
resource "time_sleep" "delivery_iam_propagation" {
  create_duration = "30s"

  triggers = {
    role_arn          = aws_iam_role.delivery.arn
    trust_policy_hash = sha256(aws_iam_role.delivery.assume_role_policy)
    role_policy_hash  = sha256(aws_iam_role_policy.delivery.policy)
  }
}
