locals {
  async_invocation_destinations = {
    service = {
      function_name      = aws_lambda_function.preprocess.function_name
      failure_bucket_arn = var.failure_bucket_arn
    }
    ci = {
      function_name      = aws_lambda_function.preprocess_ci.function_name
      failure_bucket_arn = aws_s3_bucket.processed_ci.arn
    }
  }
}

# 비동기 호출에만 적용됩니다. Jenkins의 동기 호출과 Kinesis 배치 재시도는 별도입니다.
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
