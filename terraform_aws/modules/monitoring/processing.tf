# 부분 실패 응답은 Lambda Errors에 잡히지 않을 수 있으므로 레코드 실패도 관측합니다.
resource "aws_cloudwatch_log_metric_filter" "processing_failed_records" {
  name           = "${var.name_prefix}-processing-failed-records"
  log_group_name = var.processing_log_group_name
  pattern        = "{ $.event = \"processing_summary\" }"

  metric_transformation {
    name          = "ProcessingFailedRecords"
    namespace     = "UBI/${var.name_prefix}"
    value         = "$.failed"
    default_value = 0
  }
}
