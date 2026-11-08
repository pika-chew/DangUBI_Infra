locals {
  # 전달 알람은 세 dimension을 모두 지정해야 실제 전달 지표와 일치합니다.
  delivery_dimensions = {
    ChannelName = var.channel_name
    ChannelId   = var.channel_id
    StreamName  = var.stream_name
  }

  alarms = {
    firehose_write_throttled = {
      description = "Firehose 쓰기 제한 발생. Lambda 재시도와 스트림 수신 처리량을 확인하세요."
      namespace   = "AWS/Firehose"
      metric_name = "ThrottledRecords"
      statistic   = "Sum"
      period      = 60
      evaluations = 1
      threshold   = 0
      dimensions  = { DeliveryStreamName = var.firehose_stream_name }
    }
    firehose_delivery_errors = {
      description = "Firehose 전달 오류 로그가 기록됐습니다. S3 접근 권한과 전달 로그를 확인하세요."
      namespace   = "UBI/${var.name_prefix}"
      metric_name = "FirehoseDeliveryErrorLogs"
      statistic   = "Sum"
      period      = 60
      evaluations = 1
      threshold   = 0
      dimensions  = {}
    }
    firehose_delivery_delayed = {
      description = "Firehose의 S3 미전달 데이터가 지연되고 있습니다. 전달 로그와 S3 상태를 확인하세요."
      namespace   = "AWS/Firehose"
      metric_name = "DeliveryToS3.DataFreshness"
      statistic   = "Maximum"
      period      = 60
      evaluations = 3
      threshold   = var.firehose_freshness_threshold_seconds
      dimensions  = { DeliveryStreamName = var.firehose_stream_name }
    }
    processing_async_old = {
      description = "Lambda 비동기 이벤트 대기가 5분을 넘었습니다. 함수 오류와 호출 제한을 확인하세요."
      namespace   = "AWS/Lambda"
      metric_name = "AsyncEventAge"
      statistic   = "Maximum"
      period      = 60
      evaluations = 3
      threshold   = 300000 # 밀리초, 5분
      dimensions  = { FunctionName = var.processing_function_name }
    }
    processing_async_dropped = {
      description = "Lambda 비동기 이벤트가 만료되거나 재시도를 소진했습니다. 실패 보관 S3를 확인하세요."
      namespace   = "AWS/Lambda"
      metric_name = "AsyncEventsDropped"
      statistic   = "Sum"
      period      = 60
      evaluations = 1
      threshold   = 0
      dimensions  = { FunctionName = var.processing_function_name }
    }
    kinesis_write_throttled = {
      description = "Kinesis 쓰기 제한 발생. 생산자의 재시도 및 스트림 처리량을 확인하세요."
      namespace   = "AWS/Kinesis"
      metric_name = "WriteProvisionedThroughputExceeded"
      statistic   = "Sum"
      period      = 60
      evaluations = 1
      threshold   = 0
      dimensions  = { StreamName = var.stream_name }
    }
    kinesis_read_throttled = {
      description = "Kinesis 읽기 제한 발생. 소비자의 읽기 처리량을 확인하세요."
      namespace   = "AWS/Kinesis"
      metric_name = "ReadProvisionedThroughputExceeded"
      statistic   = "Sum"
      period      = 60
      evaluations = 1
      threshold   = 0
      dimensions  = { StreamName = var.stream_name }
    }
    archive_delivery_failed = {
      description = "S3 직접 전달 실패. 전달 로그와 S3 delivery-errors/를 확인하세요."
      namespace   = "AWS/Kinesis"
      metric_name = "DeliveryToS3.FailedRecordCount"
      statistic   = "Sum"
      period      = 300
      evaluations = 1
      threshold   = 0
      dimensions  = local.delivery_dimensions
    }
    archive_delivery_delayed = {
      description = "S3 전달 데이터 지연이 목표의 두 배를 넘었습니다."
      namespace   = "AWS/Kinesis"
      metric_name = "DeliveryToS3.DataFreshness"
      statistic   = "Maximum"
      period      = 300
      evaluations = 2
      threshold   = var.delivery_freshness_seconds * 2
      dimensions  = local.delivery_dimensions
    }
    ingestion_queue_old = {
      description = "SQS에 오래 대기하는 메시지가 있습니다. 프라이빗 수집 워커를 확인하세요."
      namespace   = "AWS/SQS"
      metric_name = "ApproximateAgeOfOldestMessage"
      statistic   = "Maximum"
      period      = 60
      evaluations = 3
      threshold   = var.queue_age_threshold_seconds
      dimensions  = { QueueName = var.queue_name }
    }
    ingestion_dlq_not_empty = {
      description = "수집 워커용 SQS DLQ에 메시지가 있습니다. 원인을 확인한 후 재처리하세요."
      namespace   = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesVisible"
      statistic   = "Maximum"
      period      = 60
      evaluations = 1
      threshold   = 0
      dimensions  = { QueueName = var.dlq_name }
    }
    processing_errors = {
      description = "처리 Lambda의 예외 또는 타임아웃 발생. Lambda 로그를 확인하세요."
      namespace   = "AWS/Lambda"
      metric_name = "Errors"
      statistic   = "Sum"
      period      = 60
      evaluations = 1
      threshold   = 0
      dimensions  = { FunctionName = var.processing_function_name }
    }
    processing_throttled = {
      description = "처리 Lambda 호출 제한 발생. 계정 동시 실행 한도를 확인하세요."
      namespace   = "AWS/Lambda"
      metric_name = "Throttles"
      statistic   = "Sum"
      period      = 60
      evaluations = 1
      threshold   = 0
      dimensions  = { FunctionName = var.processing_function_name }
    }
    processing_iterator_old = {
      description = "처리 Lambda의 Kinesis 읽기가 60초 이상 지연되고 있습니다."
      namespace   = "AWS/Lambda"
      metric_name = "IteratorAge"
      statistic   = "Maximum"
      period      = 60
      evaluations = 3
      threshold   = 60000 # 밀리초
      dimensions  = { FunctionName = var.processing_function_name }
    }
    processing_record_failures = {
      description = "전처리 로그에 레코드 실패가 기록됐습니다. 함수 로그와 실패 보관 이벤트를 확인하세요."
      namespace   = "UBI/${var.name_prefix}"
      metric_name = "ProcessingFailedRecords"
      statistic   = "Sum"
      period      = 60
      evaluations = 1
      threshold   = 0
      dimensions  = {}
    }
    processing_failure_delivery_failed = {
      description = "Lambda가 재시도 소진 이벤트를 S3 실패 목적지에 보관하지 못했습니다."
      namespace   = "AWS/Lambda"
      metric_name = "DestinationDeliveryFailures"
      statistic   = "Sum"
      period      = 60
      evaluations = 1
      threshold   = 0
      dimensions  = { FunctionName = var.processing_function_name }
    }
    iot_json_parse_errors = {
      description = "IoT 규칙에서 JSON 파싱 오류가 발생했습니다. 생산자의 메시지 형식을 확인하세요."
      namespace   = "AWS/IoT"
      metric_name = "ParseError"
      statistic   = "Sum"
      period      = 60
      evaluations = 1
      threshold   = 0
      dimensions  = { RuleName = var.iot_rule_name }
    }
    iot_rule_errors = {
      description = "IoT → Lambda 호출 전달 오류가 기록됐습니다. IoT 규칙 오류 로그를 확인하세요."
      namespace   = "UBI/${var.name_prefix}"
      metric_name = "IotRuleErrors"
      statistic   = "Sum"
      period      = 60
      evaluations = 1
      threshold   = 0
      dimensions  = {}
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "pipeline" {
  for_each = local.alarms

  alarm_name          = "${var.name_prefix}-${replace(each.key, "_", "-")}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric_name
  statistic           = each.value.statistic
  period              = each.value.period
  evaluation_periods  = each.value.evaluations
  datapoints_to_alarm = each.value.evaluations
  threshold           = each.value.threshold
  comparison_operator = "GreaterThanThreshold"
  dimensions          = each.value.dimensions
  treat_missing_data  = "notBreaching"

  # 비어 있으면 콘솔 상태만 변경됩니다. 이메일·Slack 구독은 만들지 않습니다.
  alarm_actions = var.alarm_action_arns
  ok_actions    = var.alarm_action_arns
}
