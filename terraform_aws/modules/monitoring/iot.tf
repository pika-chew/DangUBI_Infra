resource "aws_cloudwatch_log_metric_filter" "iot_rule_errors" {
  name           = "${var.name_prefix}-iot-rule-errors"
  log_group_name = var.iot_error_log_group_name
  pattern        = ""

  metric_transformation {
    name          = "IotRuleErrors"
    namespace     = "UBI/${var.name_prefix}"
    value         = "1"
    default_value = 0
  }
}
