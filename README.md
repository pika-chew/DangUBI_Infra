# DangUBI_Infra

UBI 프로젝트의 Terraform·Ansible 코드입니다.

## AWS 리소스 배치

구성할 경로는 `IoT Core → 기존 서비스 Lambda → Firehose → 가공 S3 → SQS`입니다. 서비스·CI Lambda를 재사용하며, CI에는 별도 Firehose·S3·SQS를 연결합니다.

현재 작업 범위는 리소스·권한·연결 구성입니다. Lambda와 소비자의 실제 데이터 처리 기능은 별도 저장소에서 준비합니다.

- Terraform 실행 디렉토리: `terraform_aws`.
- Lambda 이미지: 기존 `terraform_aws/processing-image.auto.tfvars.json`을 자동 로드합니다. 예시 이미지 URI나 별도 이미지 변수 파일은 필요하지 않습니다.
- IoT Rule: 기존 서비스 Lambda를 대상으로 구성하며 기본값은 비활성입니다.
- S3→SQS 알림: 루트 기본값으로 서비스·CI 모두 생성합니다. 객체가 `firehose/processed/` 아래에 생성되면 알림이 전송됩니다.
- 기존 CI Lambda 이미지: `ignore_changes`를 유지하므로 Terraform이 덮어쓰지 않습니다.

기존 Kinesis Stream·Channel·Lambda 이벤트 소스 매핑과 전용 로그는 코드에서 제거했습니다. 실제 적용 시 미처리 데이터와 전용 로그도 삭제 대상이 됩니다. 기존 raw·가공 S3와 객체, SQS, 서비스·CI Lambda, ECR, tfstate S3와 backend는 유지합니다.

AWSCC provider는 기존 state의 Channel 삭제를 위해 유지합니다. 기존 KMS 키도 삭제를 보류했습니다. 이 두 항목은 실제 삭제 결과와 사용처를 확인한 뒤 별도로 정리합니다.

리소스 코드 작성과 실제 AWS 배포는 별개입니다. 최근 리소스 배치 설정 변경에는 구성 검증·테스트·plan·apply를 수행하지 않았습니다.

모듈 구성과 변경 이력은 [파이프라인 설계 문서](docs/aws-firehose-pipeline-design.md)를 참고하세요.
