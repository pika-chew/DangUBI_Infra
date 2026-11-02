resource "aws_kms_key" "telemetry" {
  description             = "${var.name_prefix} Kinesis source stream encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  # 기본 키 정책은 계정의 IAM 정책으로 이 키의 접근 권한을 부여할 수 있게 합니다.
  # S3 직접 전달은 AWS 관리형 alias/aws/kinesis로 암호화한 소스를 지원하지 않습니다.
  tags = {
    Name = "${var.name_prefix}-kinesis"
  }
}
