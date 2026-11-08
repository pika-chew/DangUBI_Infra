# processing_summary 로그를 유지하는 이미지의 레코드 실패를 내장 Lambda 지표와 함께 관측합니다.
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
