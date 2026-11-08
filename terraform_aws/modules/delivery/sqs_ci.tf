resource "aws_sqs_queue" "ingestion_ci" {
  name                       = "${var.name_prefix}-ingestion-ci"
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20
  visibility_timeout_seconds = var.visibility_timeout_seconds
  sqs_managed_sse_enabled    = true
}
