resource "aws_cloudwatch_log_group" "delivery" {
  name              = "/aws/kinesis/${var.name_prefix}-archive"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_stream" "delivery" {
  name           = "DestinationDelivery"
  log_group_name = aws_cloudwatch_log_group.delivery.name
}
