# Rule 비활성 상태에도 기존 서비스 Lambda의 호출 권한을 준비합니다.
resource "aws_lambda_permission" "iot" {
  count = var.iot_rule_arn == null ? 0 : 1

  statement_id   = "AllowTelemetryIoTRule"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.preprocess.function_name
  principal      = "iot.amazonaws.com"
  source_arn     = var.iot_rule_arn
  source_account = var.aws_account_id
}
