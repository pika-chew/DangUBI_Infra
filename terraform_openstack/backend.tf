terraform {
  backend "s3" {
    # 초기화할 때 state 전용 Swift 컨테이너 이름을 -backend-config="bucket=..."으로 전달합니다.
    key = "openstack/terraform.tfstate"

    # Swift S3 API에서 검증한 서명 리전과 경로 방식 주소를 사용합니다.
    region         = "us-east-1"
    endpoints      = { s3 = "http://10.10.0.10:8081" }
    use_path_style = true
    use_lockfile   = true

    # Swift는 AWS의 계정 조회·인증 API를 제공하지 않습니다.
    # Swift S3 키는 AWS_ACCESS_KEY_ID와 AWS_SECRET_ACCESS_KEY 환경변수로 전달합니다.
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
