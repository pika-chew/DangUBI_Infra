#!/bin/sh
# terraform apply 이후 핵심 리소스가 실제로 동작 가능한 상태인지 확인합니다.
# smoke.env(terraform output 값)가 있는 디렉터리에서 실행합니다: sh scripts/smoke-test.sh
# 실패 항목은 smoke-failures.txt에 남기고 종료 코드 1로 끝납니다.

set -u
. ./smoke.env

failed=0
: > smoke-failures.txt

# $1: 항목 이름, $2: 실제 값, $3: 기대 값(정규식)
check() {
    if printf '%s' "$2" | grep -Eqx "$3"; then
        echo "[OK]   $1: $2"
    else
        echo "[FAIL] $1: $2 (기대: $3)"
        echo "- $1: $2 (기대: $3)" >> smoke-failures.txt
        failed=1
    fi
}

bucket_status() {
    aws s3api head-bucket --bucket "$1" > /dev/null 2>&1 && echo OK || echo "접근 불가"
}

check "Firehose 상태" \
    "$(aws firehose describe-delivery-stream --delivery-stream-name "$FIREHOSE_STREAM_NAME" \
        --query DeliveryStreamDescription.DeliveryStreamStatus --output text 2>&1)" \
    "ACTIVE"

check "Lambda 상태" \
    "$(aws lambda get-function-configuration --function-name "$PROCESSING_FUNCTION_NAME" \
        --query State --output text 2>&1)" \
    "Active"

check "Lambda 마지막 업데이트" \
    "$(aws lambda get-function-configuration --function-name "$PROCESSING_FUNCTION_NAME" \
        --query LastUpdateStatus --output text 2>&1)" \
    "Successful"

check "IoT 규칙" \
    "$(aws iot get-topic-rule --rule-name "$IOT_RULE_NAME" \
        --query rule.ruleName --output text 2>&1)" \
    "$IOT_RULE_NAME"

check "SQS 수집 큐" \
    "$(aws sqs get-queue-attributes --queue-url "$INGESTION_QUEUE_URL" \
        --attribute-names QueueArn --query Attributes.QueueArn --output text 2>&1)" \
    "arn:aws:sqs:.*"

check "SQS DLQ" \
    "$(aws sqs get-queue-attributes --queue-url "$INGESTION_DLQ_URL" \
        --attribute-names QueueArn --query Attributes.QueueArn --output text 2>&1)" \
    "arn:aws:sqs:.*"

# s3_queue_notifications_enabled가 false면 알림을 만들지 않으므로 확인하지 않습니다.
if [ "$S3_QUEUE_NOTIFICATIONS_ENABLED" = "true" ]; then
    check "S3 → SQS 알림" \
        "$(aws s3api get-bucket-notification-configuration --bucket "$PROCESSED_BUCKET_NAME" \
            --query "QueueConfigurations[?QueueArn=='$INGESTION_QUEUE_ARN'].QueueArn | [0]" --output text 2>&1)" \
        "$INGESTION_QUEUE_ARN"
fi

check "S3 raw 버킷" "$(bucket_status "$RAW_BUCKET_NAME")" "OK"
check "S3 processed 버킷" "$(bucket_status "$PROCESSED_BUCKET_NAME")" "OK"

exit $failed
