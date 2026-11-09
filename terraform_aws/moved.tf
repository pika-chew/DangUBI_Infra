# 모듈을 분리해도 기존 AWS 리소스를 이어받도록 이전 주소와 연결합니다.

moved {
  from = module.processing.aws_s3_bucket.processed
  to   = module.delivery.aws_s3_bucket.processed
}

moved {
  from = module.processing.aws_s3_bucket_public_access_block.processed
  to   = module.delivery.aws_s3_bucket_public_access_block.processed
}

moved {
  from = module.processing.aws_s3_bucket_server_side_encryption_configuration.processed
  to   = module.delivery.aws_s3_bucket_server_side_encryption_configuration.processed
}

moved {
  from = module.processing.aws_s3_bucket_versioning.processed
  to   = module.delivery.aws_s3_bucket_versioning.processed
}

moved {
  from = module.processing.aws_s3_bucket_policy.processed_https_only
  to   = module.delivery.aws_s3_bucket_policy.processed_https_only
}

moved {
  from = module.processing.aws_sqs_queue.ingestion_dlq
  to   = module.delivery.aws_sqs_queue.ingestion_dlq
}

moved {
  from = module.processing.aws_sqs_queue.ingestion
  to   = module.delivery.aws_sqs_queue.ingestion
}

moved {
  from = module.processing.aws_sqs_queue_redrive_allow_policy.ingestion_dlq
  to   = module.delivery.aws_sqs_queue_redrive_allow_policy.ingestion_dlq
}

moved {
  from = module.processing.aws_kinesis_firehose_delivery_stream.processed
  to   = module.delivery.aws_kinesis_firehose_delivery_stream.processed
}

moved {
  from = module.processing.aws_iam_role.firehose
  to   = module.delivery.aws_iam_role.firehose
}

moved {
  from = module.processing.aws_iam_role_policy.firehose
  to   = module.delivery.aws_iam_role_policy.firehose
}

moved {
  from = module.processing.time_sleep.firehose_iam_propagation
  to   = module.delivery.time_sleep.firehose_iam_propagation
}

moved {
  from = module.processing.aws_cloudwatch_log_group.firehose
  to   = module.delivery.aws_cloudwatch_log_group.firehose
}

moved {
  from = module.processing.aws_cloudwatch_log_stream.firehose
  to   = module.delivery.aws_cloudwatch_log_stream.firehose
}
