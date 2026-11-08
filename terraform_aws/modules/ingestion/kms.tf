resource "aws_kms_key" "telemetry" {
  description             = "${var.name_prefix} Kinesis source stream encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  # 다른 사용처와 복구 필요성을 확인하기 전에는 기존 키를 삭제하지 않습니다.
  # 스트림 제거와 별개로 기존 리소스 주소와 키 설정을 유지합니다.
  tags = {
    Name = "${var.name_prefix}-kinesis"
  }
}
