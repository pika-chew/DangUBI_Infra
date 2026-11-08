locals {
  async_invocation_destinations = {
    service = {
      function_name      = aws_lambda_function.preprocess.function_name
      failure_bucket_arn = var.failure_bucket_arn
    }
    ci = {
      function_name      = aws_lambda_function.preprocess_ci.function_name
      failure_bucket_arn = var.delivery_destinations["ci"].bucket_arn
    }
  }
}

# 비동기 호출에만 적용되며 Jenkins의 동기 호출에는 적용되지 않습니다.
resource "aws_lambda_function_event_invoke_config" "preprocess" {
  for_each = local.async_invocation_destinations

  function_name                = each.value.function_name
  maximum_retry_attempts       = 2
  maximum_event_age_in_seconds = 21600

  destination_config {
    on_failure {
      destination = each.value.failure_bucket_arn
    }
  }

  depends_on = [time_sleep.preprocess_iam_propagation]
}
