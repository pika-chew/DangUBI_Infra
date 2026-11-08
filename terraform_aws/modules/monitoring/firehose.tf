# 전달 오류 전용 로그의 기록 수이며, 실패한 데이터 레코드 수와는 다릅니다.
resource "aws_cloudwatch_log_metric_filter" "firehose_delivery_errors" {
  name           = "${var.name_prefix}-firehose-delivery-errors"
  log_group_name = var.firehose_log_group_name
  pattern        = ""

  metric_transformation {
    name          = "FirehoseDeliveryErrorLogs"
    namespace     = "UBI/${var.name_prefix}"
    value         = "1"
    default_value = 0
  }
}
