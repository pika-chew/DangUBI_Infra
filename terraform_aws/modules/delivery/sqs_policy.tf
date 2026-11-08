# 알림 활성화와 별개로 수신 권한을 준비하며, 각 큐에 대응하는 버킷만 허용합니다.
resource "aws_sqs_queue_policy" "s3_notifications" {
  for_each = local.s3_notification_destinations

  queue_url = each.value.queue_url
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowProcessedObjectNotifications"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = ["sqs:SendMessage"]
      Resource  = each.value.queue_arn
      Condition = {
        ArnEquals    = { "aws:SourceArn" = each.value.bucket_arn }
        StringEquals = { "aws:SourceAccount" = var.aws_account_id }
      }
    }]
  })
}
