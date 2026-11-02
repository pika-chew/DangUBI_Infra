data "aws_partition" "current" {}

data "aws_iot_endpoint" "data" {
  endpoint_type = "iot:Data-ATS"
}

locals {
  iot_rule_name = "${replace(var.name_prefix, "-", "_")}_telemetry"
  iot_rule_arn  = "arn:${data.aws_partition.current.partition}:iot:${var.aws_region}:${var.aws_account_id}:rule/${local.iot_rule_name}"
}

resource "aws_iot_thing" "vehicle" {
  for_each = var.device_csrs

  name       = "${var.name_prefix}-${each.key}"
  attributes = { vehicleId = each.key }
}

resource "aws_iot_certificate" "vehicle" {
  for_each = var.device_csrs

  # CSR에는 공개키만 포함됩니다. 개인키는 로컬에서 보관합니다.
  csr    = each.value
  active = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iot_policy" "vehicle" {
  for_each = var.device_csrs

  name = "${var.name_prefix}-${each.key}-device"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["iot:Connect"]
        Resource = "arn:${data.aws_partition.current.partition}:iot:${var.aws_region}:${var.aws_account_id}:client/${aws_iot_thing.vehicle[each.key].name}"
        Condition = {
          Bool = { "iot:Connection.Thing.IsAttached" = "true" }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["iot:Publish"]
        Resource = "arn:${data.aws_partition.current.partition}:iot:${var.aws_region}:${var.aws_account_id}:topic/${var.topic_prefix}/${each.key}/telemetry"
      }
    ]
  })
}

resource "aws_iot_policy_attachment" "vehicle" {
  for_each = var.device_csrs

  policy = aws_iot_policy.vehicle[each.key].name
  target = aws_iot_certificate.vehicle[each.key].arn
}

resource "aws_iot_thing_principal_attachment" "vehicle" {
  for_each = var.device_csrs

  thing     = aws_iot_thing.vehicle[each.key].name
  principal = aws_iot_certificate.vehicle[each.key].arn
}

resource "aws_cloudwatch_log_group" "iot_errors" {
  name              = "/aws/iot/${var.name_prefix}-rule-errors"
  retention_in_days = var.log_retention_days
}

resource "aws_iot_topic_rule" "telemetry" {
  name        = local.iot_rule_name
  description = "Route authenticated vehicle JSON messages to Kinesis"
  enabled     = var.rule_enabled
  sql         = "SELECT *, topic(4) AS vehicleId FROM '${var.topic_prefix}/+/telemetry'"
  sql_version = "2016-03-23"

  kinesis {
    stream_name = aws_kinesis_stream.telemetry.name
    # IoT 치환식은 Terraform이 아니라 IoT 서비스가 평가합니다.
    # ubi/dev/vehicles/vehicle-001/telemetry의 네 번째 요소가 차량 ID입니다.
    partition_key = "$${topic(4)}"
    role_arn      = aws_iam_role.iot_rule.arn
  }

  error_action {
    cloudwatch_logs {
      log_group_name = aws_cloudwatch_log_group.iot_errors.name
      role_arn       = aws_iam_role.iot_rule.arn
    }
  }

  depends_on = [time_sleep.iot_iam_propagation]
}
