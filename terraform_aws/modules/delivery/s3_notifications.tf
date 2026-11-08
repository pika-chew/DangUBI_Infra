locals {
  s3_notification_destinations = {
    service = {
      bucket_id  = aws_s3_bucket.processed.id
      bucket_arn = aws_s3_bucket.processed.arn
      queue_url  = aws_sqs_queue.ingestion.url
      queue_arn  = aws_sqs_queue.ingestion.arn
      enabled    = var.s3_queue_notifications_enabled
    }
    ci = {
      bucket_id  = aws_s3_bucket.processed_ci.id
      bucket_arn = aws_s3_bucket.processed_ci.arn
      queue_url  = aws_sqs_queue.ingestion_ci.url
      queue_arn  = aws_sqs_queue.ingestion_ci.arn
      enabled    = var.ci_s3_queue_notifications_enabled
    }
  }
}

# 수신 측이 S3 객체 알림을 처리할 준비가 된 환경만 활성화합니다.
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
    filter_prefix = "firehose/processed/"
  }

  depends_on = [aws_sqs_queue_policy.s3_notifications]
}
