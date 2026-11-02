resource "aws_cloudwatch_dashboard" "pipeline" {
  dashboard_name = "${var.name_prefix}-pipeline"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title = "Kinesis input / output records", region = var.aws_region
          view  = "timeSeries", period = 60, stat = "Sum"
          metrics = [
            ["AWS/Kinesis", "IncomingRecords", "StreamName", var.stream_name],
            ["AWS/Kinesis", "GetRecords.Records", "StreamName", var.stream_name]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title = "Kinesis throttling", region = var.aws_region
          view  = "timeSeries", period = 60, stat = "Sum"
          metrics = [
            ["AWS/Kinesis", "WriteProvisionedThroughputExceeded", "StreamName", var.stream_name],
            ["AWS/Kinesis", "ReadProvisionedThroughputExceeded", "StreamName", var.stream_name]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title = "S3 delivered / failed records", region = var.aws_region
          view  = "timeSeries", period = 300, stat = "Sum"
          metrics = [
            ["AWS/Kinesis", "DeliveryToS3.SuccessfulRecordCount", "ChannelName", var.channel_name, "ChannelId", var.channel_id, "StreamName", var.stream_name],
            ["AWS/Kinesis", "DeliveryToS3.FailedRecordCount", "ChannelName", var.channel_name, "ChannelId", var.channel_id, "StreamName", var.stream_name]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title = "S3 delivery freshness (seconds)", region = var.aws_region
          view  = "timeSeries", period = 300, stat = "Maximum"
          metrics = [
            ["AWS/Kinesis", "DeliveryToS3.DataFreshness", "ChannelName", var.channel_name, "ChannelId", var.channel_id, "StreamName", var.stream_name]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title = "SQS backlog / in-flight / DLQ", region = var.aws_region
          view  = "timeSeries", period = 60, stat = "Maximum"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.queue_name],
            ["AWS/SQS", "ApproximateNumberOfMessagesNotVisible", "QueueName", var.queue_name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.dlq_name]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6
        properties = {
          title = "SQS oldest message age (seconds)", region = var.aws_region
          view  = "timeSeries", period = 60, stat = "Maximum"
          metrics = [
            ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", var.queue_name]
          ]
        }
      },
      {
        type = "log", x = 0, y = 18, width = 24, height = 6
        properties = {
          title = "Kinesis S3 delivery logs", region = var.aws_region
          view  = "table"
          query = "SOURCE '${var.delivery_log_group_name}' | fields @timestamp, @message | sort @timestamp desc | limit 50"
        }
      },
      {
        type = "metric", x = 0, y = 24, width = 12, height = 6
        properties = {
          title = "Processing Lambda invocations / errors / throttles", region = var.aws_region
          view  = "timeSeries", period = 60, stat = "Sum"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.processing_function_name],
            ["AWS/Lambda", "Errors", "FunctionName", var.processing_function_name],
            ["AWS/Lambda", "Throttles", "FunctionName", var.processing_function_name],
            ["AWS/Lambda", "DestinationDeliveryFailures", "FunctionName", var.processing_function_name]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 24, width = 12, height = 6
        properties = {
          title   = "Processing Kinesis iterator age (milliseconds)", region = var.aws_region
          view    = "timeSeries", period = 60, stat = "Maximum"
          metrics = [["AWS/Lambda", "IteratorAge", "FunctionName", var.processing_function_name]]
        }
      },
      {
        type = "metric", x = 0, y = 30, width = 12, height = 6
        properties = {
          title   = "Processing failed records", region = var.aws_region
          view    = "timeSeries", period = 60, stat = "Sum"
          metrics = [["UBI/${var.name_prefix}", "ProcessingFailedRecords"]]
        }
      },
      {
        type = "log", x = 12, y = 30, width = 12, height = 6
        properties = {
          title = "Processing Lambda logs", region = var.aws_region
          view  = "table"
          query = "SOURCE '${var.processing_log_group_name}' | fields @timestamp, @message | sort @timestamp desc | limit 50"
        }
      },
      {
        type = "metric", x = 0, y = 36, width = 12, height = 6
        properties = {
          title = "IoT rule matched messages / JSON parse errors", region = var.aws_region
          view  = "timeSeries", period = 60, stat = "Sum"
          metrics = [
            ["AWS/IoT", "TopicMatch", "RuleName", var.iot_rule_name],
            ["AWS/IoT", "ParseError", "RuleName", var.iot_rule_name],
            ["UBI/${var.name_prefix}", "IotRuleErrors"]
          ]
        }
      },
      {
        type = "log", x = 12, y = 36, width = 12, height = 6
        properties = {
          title = "IoT rule error logs", region = var.aws_region
          view  = "table"
          query = "SOURCE '${var.iot_error_log_group_name}' | fields @timestamp, @message | sort @timestamp desc | limit 50"
        }
      }
    ]
  })
}
