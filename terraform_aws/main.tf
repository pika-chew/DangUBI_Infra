locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "ingestion" {
  source = "./modules/ingestion"

  name_prefix        = local.name_prefix
  aws_region         = var.aws_region
  aws_account_id     = var.aws_account_id
  device_csrs        = { for id, csr_path in var.iot_device_csr_paths : id => file(csr_path) }
  topic_prefix       = "${var.project_name}/${var.environment}/vehicles"
  log_retention_days = var.cloudwatch_log_retention_days
  rule_enabled       = var.iot_rule_enabled
}

module "archive" {
  source = "./modules/archive"

  name_prefix                = local.name_prefix
  aws_account_id             = var.aws_account_id
  aws_region                 = var.aws_region
  stream_arn                 = module.ingestion.stream_arn
  stream_kms_key_arn         = module.ingestion.stream_kms_key_arn
  delivery_freshness_seconds = var.archive_delivery_freshness_seconds
  log_retention_days         = var.cloudwatch_log_retention_days
  tags                       = local.common_tags

  providers = {
    aws   = aws
    awscc = awscc
  }
}

module "delivery" {
  source = "./modules/delivery"

  name_prefix                         = local.name_prefix
  aws_region                          = var.aws_region
  aws_account_id                      = var.aws_account_id
  log_retention_days                  = var.cloudwatch_log_retention_days
  visibility_timeout_seconds          = var.sqs_visibility_timeout_seconds
  firehose_buffering_size_mib         = var.firehose_buffering_size_mib
  firehose_buffering_interval_seconds = var.firehose_buffering_interval_seconds
  s3_queue_notifications_enabled      = var.s3_queue_notifications_enabled
  ci_s3_queue_notifications_enabled   = var.ci_s3_queue_notifications_enabled
}

module "processing" {
  source = "./modules/processing"

  image_uri             = var.processing_image_uri
  name_prefix           = local.name_prefix
  stream_arn            = module.ingestion.stream_arn
  stream_kms_key_arn    = module.ingestion.stream_kms_key_arn
  failure_bucket_arn    = module.archive.bucket_arn
  aws_region            = var.aws_region
  aws_account_id        = var.aws_account_id
  log_retention_days    = var.cloudwatch_log_retention_days
  batch_size            = var.processing_batch_size
  consumer_enabled      = var.processing_consumer_enabled
  iot_rule_arn          = module.ingestion.iot_rule_arn
  delivery_destinations = module.delivery.lambda_destinations
}

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix                 = local.name_prefix
  aws_region                  = var.aws_region
  stream_name                 = module.ingestion.stream_name
  channel_name                = module.archive.channel_name
  channel_id                  = module.archive.channel_id
  delivery_log_group_name     = module.archive.delivery_log_group_name
  queue_name                  = module.delivery.queue_name
  dlq_name                    = module.delivery.dlq_name
  delivery_freshness_seconds  = var.archive_delivery_freshness_seconds
  queue_age_threshold_seconds = var.sqs_age_alarm_threshold_seconds
  alarm_action_arns           = var.cloudwatch_alarm_action_arns
  processing_function_name    = module.processing.function_name
  processing_log_group_name   = module.processing.function_log_group_name
  iot_rule_name               = module.ingestion.iot_rule_name
  iot_error_log_group_name    = module.ingestion.iot_error_log_group_name
}
