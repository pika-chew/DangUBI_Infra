# 호출 권한만 준비합니다. IoT Rule의 실제 전송 대상은 전환 단계에서 변경합니다.
resource "aws_lambda_permission" "iot" {
  count = var.iot_rule_arn == null ? 0 : 1

  statement_id   = "AllowTelemetryIoTRule"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.preprocess.function_name
  principal      = "iot.amazonaws.com"
  source_arn     = var.iot_rule_arn
  source_account = var.aws_account_id
}
