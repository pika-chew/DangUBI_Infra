resource "aws_cloudwatch_log_group" "firehose" {
  for_each = local.firehose_destinations

  name              = "/aws/kinesisfirehose/${each.value.stream_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_stream" "firehose" {
  for_each = local.firehose_destinations

  name           = "DestinationDelivery"
  log_group_name = aws_cloudwatch_log_group.firehose[each.key].name
}
