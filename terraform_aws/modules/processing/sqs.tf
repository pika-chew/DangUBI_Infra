resource "aws_sqs_queue" "ingestion_dlq" {
  name                      = "${var.name_prefix}-ingestion-dlq"
  message_retention_seconds = 1209600 # 14일
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "ingestion" {
  name                       = "${var.name_prefix}-ingestion"
  message_retention_seconds  = 1209600                        # 14일. 복구 후 백로그 처리 시간도 보존 기간에 포함됩니다.
  receive_wait_time_seconds  = 20                             # 롱 폴링 (20초, 불필요한 API 호출 비용 및 CPU 점유율을 줄이기 위해)
  visibility_timeout_seconds = var.visibility_timeout_seconds # 처리 중 숨김 시간이며 중복 전달을 완전히 방지하지는 않습니다.
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ingestion_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "ingestion_dlq" {
  queue_url = aws_sqs_queue.ingestion_dlq.url

  redrive_allow_policy = jsonencode({ # 원본 큐와 DLQ 둘 다 Standard Queue
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.ingestion.arn]
  })
}
