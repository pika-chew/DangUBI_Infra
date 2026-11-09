locals {
  s3_notification_destinations = {
    service = {
      bucket_id  = aws_s3_bucket.processed.id
      bucket_arn = aws_s3_bucket.processed.arn
      queue_url  = aws_sqs_queue.ingestion.url
      queue_arn  = aws_sqs_queue.ingestion.arn
      enabled    = var.s3_queue_notifications_enabled
    }
  }
}

# 서비스 가공 경로만 알립니다. 같은 버킷의 CI 결과는 다른 prefix에 저장합니다.
# 버킷의 다른 알림이 있다면 활성화 전에 이 리소스의 설정에 함께 반영해야 합니다.
resource "aws_s3_bucket_notification" "processed" {
  for_each = {
    for name, destination in local.s3_notification_destinations : name => destination
    if destination.enabled
  }

  bucket = each.value.bucket_id

  queue {
    id            = "${each.key}-firehose-processed-objects"
    queue_arn     = each.value.queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = local.firehose_destinations.service.data_prefix
  }

  depends_on = [aws_sqs_queue_policy.s3_notifications]
}
