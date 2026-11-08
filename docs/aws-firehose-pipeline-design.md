# AWS Firehose 파이프라인 전환 설계

상태: 5단계 S3→SQS 연결 설정을 `dadabb3`로 커밋한 뒤, IoT Rule을 기존 서비스 Lambda 직접 호출로 고정했다. Kinesis 선택·복귀 분기는 두지 않으며 Kinesis 리소스 자체는 후속 정리 단계에서 제거한다. Lambda 소스 수정·이미지 준비는 사용자 측에서 별도로 진행한다. AWS에는 적용하지 않았다.

## 1. 목표와 작업 범위

목표 경로는 `IoT Core → 기존 서비스 Lambda → Firehose → S3 → SQS`다.

- 서비스 Lambda와 임시 CI Lambda를 모두 재사용한다. 새 Lambda 함수는 만들지 않는다.
- Lambda 소스는 기존처럼 별도 `DangUBI_Lambda` 저장소에서 관리한다. 이 저장소로 코드를 복사하거나 구현 언어를 변경하지 않는다.
- 별도 저장소에서 빌드한 ECR 컨테이너 이미지를 기존 Lambda에 연결한다. ECR 저장소와 digest URI를 사용하는 배포 방식을 유지한다.
- 사용자 결정: 새 정상 수집 데이터는 가공 결과만 보관한다. 가공 전 원본의 별도 보관 경로는 추가하지 않는다.
- 이 저장소의 변경 범위는 Terraform의 Firehose, IAM, Lambda 환경 변수·호출 설정, IoT Rule, S3 알림, 모니터링과 문서다.
- Kinesis 제거와 새 경로 연결을 한 번에 적용하지 않는다. 준비·전환·제거를 나눈다.

## 2. 기존 리소스의 처리

아래는 코드에서 확인한 리소스 주소다. AWS의 현재 배포 상태는 조회하지 않았다.

### 그대로 사용할 리소스

- Terraform state용 S3 버킷 `ubi-tfstate-821527508076-ap-northeast-2`와 버전 관리·암호화·공개 접근 차단·버킷 정책.
- `terraform_aws/bootstrap`의 `aws_s3_bucket.state` 및 관련 설정. 서비스 모듈과 별도 state로 관리하며 이번 파이프라인 변경에서 수정·제거하지 않는다.
- state 버킷의 기존 `prevent_destroy = true`, `force_destroy = false` 보호 설정도 유지한다.
- 서비스 backend의 `ubi/dev/terraform.tfstate`, bootstrap backend의 `bootstrap/terraform.tfstate`와 S3 잠금 설정. 두 backend 설정을 그대로 유지한다.
- `module.processing.aws_lambda_function.preprocess`: 서비스 전처리 함수.
- `module.processing.aws_lambda_function.preprocess_ci`: Jenkins가 직접 호출하는 CI 함수.
- `module.processing.aws_ecr_repository.preprocess`: 이미지 저장소.
- `module.processing.aws_iam_role.preprocess`: 두 함수가 공유하는 실행 역할.
- `module.delivery.aws_s3_bucket.processed`: 새 서비스 Firehose의 저장 목적지.
- `module.delivery.aws_s3_bucket.processed_ci`: 새 CI Firehose의 저장 목적지.
- `module.delivery.aws_sqs_queue.ingestion` 및 `ingestion_dlq`: 서비스 수집 큐와 DLQ.
- `module.delivery.aws_sqs_queue.ingestion_ci`: CI 결과 확인용 큐.
- `module.archive.aws_s3_bucket.raw`: 기존 원본·실패 기록 보관 버킷. 기존 객체와 버킷을 유지한다.
- 기존 IoT Thing, 인증서, 디바이스 정책과 연결, Topic Rule.

AWS 이름과 설정은 유지하고, 저장·전달 리소스의 Terraform 주소만 `module.processing`에서 `module.delivery`로 옮긴다. 루트 `terraform_aws/moved.tf`의 20개 `moved` 블록으로 이전 주소와 새 주소를 연결한다. `for_each`의 `service`·`ci` 키도 그대로 유지한다. 기존 state에 없는 Firehose 등은 이전 단계의 추가 계획에 따라 새로 생성될 수 있다.

### 모듈별 역할

- `ingestion`: IoT 장치·인증서·정책·Rule. 기존 Kinesis·KMS는 전환 완료까지 이곳에 유지한다.
- `processing`: 서비스·CI Lambda, ECR, Lambda 실행 역할·로그·호출 권한·비동기 설정. 기존 Kinesis 이벤트 소스 매핑도 제거 단계 전까지 유지한다.
- `delivery`: Firehose, 가공 S3, SQS, Firehose 실행 역할·로그, S3 알림과 SQS 수신 정책. S3 알림은 환경별 플래그를 켤 때만 생성한다.
- `archive`: 기존 raw 버킷·과거 원본·실패 기록과 전환 완료 전의 Channel을 유지한다. Channel 정의 파일은 새 delivery 모듈과 구분하도록 `kinesis_channel.tf`로 이름을 정리한다. 파일명 변경으로 리소스 주소는 바뀌지 않는다.
- `monitoring`: 내부 파일을 변경하지 않는다. 루트에서 수집 큐 정보를 받는 참조만 delivery 출력으로 연결한다.

`delivery.lambda_destinations`는 서비스·CI별 버킷 이름·ARN, 큐 URL·ARN·메시지 크기, Firehose 이름·ARN을 묶어 `processing.delivery_destinations`로 전달한다. 기존 Lambda 환경 변수의 실제 값은 유지하며, 버킷 보호 설정의 생성 순서도 delivery 출력의 의존성으로 이어간다. 외부 스크립트·Jenkins 호환성을 위해 루트 output 이름은 바꾸지 않는다.

모듈 이동은 로컬 코드 변경만으로 원격 state를 수정하지 않는다. 최신 plan에서 이동과 추가·수정·삭제 내역을 확인한 뒤 apply해야 state에 새 주소가 반영된다. `moved` 블록은 이전 state를 사용하는 환경을 위해 유지한다.

### 추가할 리소스

- 서비스용 Direct PUT Firehose와 CI용 Direct PUT Firehose 각각 1개.
- Firehose가 S3에 쓰고 로그를 남길 실행 역할·정책·로그 리소스.
- 서비스·CI S3 버킷의 알림 설정과 SQS 수신 정책.
- IoT Rule이 기존 서비스 Lambda를 호출할 수 있는 Lambda 리소스 정책.
- 비동기 Lambda 호출의 재시도·실패 목적지 설정과 새 경로의 모니터링.

### 전환 이후 제거할 리소스

- `module.ingestion.aws_kinesis_stream.telemetry`.
- `module.archive.awscc_kinesis_channel.raw`.
- `module.processing.aws_lambda_event_source_mapping.telemetry`.
- 위 경로에만 필요한 IAM 권한, 출력값, 변수, 로그·알람.

Kinesis 암호화용 KMS 키는 사용처와 복구 필요성을 확인한 후 별도로 정리한다. 기존 raw 버킷과 그 객체는 Channel 제거 대상에 포함하지 않는다.

## 3. Firehose와 S3 저장 방식

다음 수치는 구현을 시작하기 위한 제안값이며, 이미 적용된 설정이 아니다.

2단계 코드에는 아래 기본값과 서비스·CI Firehose를 추가했다. 4단계에서는 기존 Lambda의 권한·환경 변수와 비동기 실패 설정 및 IoT 호출 권한을 준비한다. 5단계에서 S3 알림과 수신 정책의 코드를 추가하되 알림 기본값은 꺼둔다. IoT Rule은 기존 서비스 Lambda만 직접 호출하도록 변경한다. AWS 적용 전 이미지·소비자 준비가 필요하다. AWS에는 아직 적용하지 않았다.

- 입력: Lambda가 직접 쓰는 Direct PUT. Firehose 내부에 추가 변환 Lambda를 연결하지 않는다.
- 서비스 스트림 이름 제안: `${name_prefix}-processed-firehose`.
- CI 스트림 이름 제안: `${name_prefix}-processed-ci-firehose`.
- 버퍼: 크기 `5 MiB`, 시간 `60초`. 두 값을 변수로 노출한다.
- 형식: UTF-8 JSON Lines, GZIP 압축. 한 줄은 전처리 결과 1건이고 한 S3 객체에는 여러 건이 들어갈 수 있다.
- 파일 확장자: `.jsonl.gz`. Lambda가 실제 JSON Lines를 보내는 것은 외부 이미지의 책임이며 확장자 설정이 본문 형식을 검증하거나 변환하지 않는다.
- 레코드 끝에 줄바꿈을 붙이는 책임은 외부 Lambda 이미지에 둔다. Firehose의 자동 줄바꿈 기능을 함께 켜서 이중으로 붙이지 않는다.
- 저장 prefix: `firehose/processed/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/`.
- prefix의 시간은 Firehose 도착 시각 기준 UTC다. 단말 측정 시각이나 한국 시각의 날짜별 분류로 해석하지 않는다.
- 오류 prefix는 정상 경로 밖의 `firehose-errors/` 아래로 둔다. 표현식을 사용하면 `!{firehose:error-output-type}`을 포함한다.
- 기존 S3 암호화·공개 접근 차단을 유지하고, 서비스 버킷의 버전 관리와 CI 버킷의 테스트 데이터 수명주기를 유지한다.
- Firehose 수신 버퍼는 AWS 소유 키로 암호화하고, S3 객체에는 기존 SSE-S3를 사용한다. 원본 별도 백업은 켜지 않는다.

서비스·CI 설정은 `module.delivery.aws_kinesis_firehose_delivery_stream.processed["service"]`와 `["ci"]`로 관리한다. 버퍼 크기와 시간은 루트의 `firehose_buffering_size_mib`와 `firehose_buffering_interval_seconds`로 조정한다. 스트림별로 목적지 버킷·prefix·로그에 접근하는 별도 Firehose 실행 역할을 사용한다.

버퍼 값은 힌트다. `60초`를 종단 간 전달 지연의 상한으로 약속하지 않는다. S3 쓰기·이벤트 알림·SQS 소비 시간도 추가된다. [버퍼 설정](https://docs.aws.amazon.com/firehose/latest/APIReference/API_BufferingHints.html), [레코드 결합](https://docs.aws.amazon.com/firehose/latest/dev/basic-deliver.html), [prefix 시간 기준](https://docs.aws.amazon.com/firehose/latest/dev/s3-prefixes.html)

기존 Lambda의 `processed/` 직접 쓰기와 새 Firehose 경로를 구분하므로, 전환 준비 중 기존 파일이 새 SQS 알림을 발생시키지 않는다.

### 원본 데이터 보관 정책

사용자는 새 정상 수집 데이터의 가공 결과만 보관하기로 결정했다. 새 주 경로의 S3에는 Lambda가 가공한 결과를 저장하며, 가공 전 원본을 별도로 복제하는 경로는 추가하지 않는다.

기존 raw 버킷과 과거 원본 객체는 유지한다. 기존 Channel은 전환 기간의 적체 처리가 끝날 때까지 유지하고 7단계에서 제거한다. 제거 이후에는 해당 경로로 새 원본이 쌓이지 않는다. 가공 과정에서 제외한 필드는 새 저장 결과만으로 복원할 수 없다.

6절의 Lambda 최종 실패 기록은 장애 복구용으로 별도 보관하며, 실패한 입력 원문이 포함될 수 있다. 정상 데이터의 원본을 계속 수집하는 경로와 구분한다.

## 4. 외부 Lambda 이미지와의 연결 계약

Terraform은 입력·출력 코드를 구현하지 않는다. 다음 기능을 지원하는 이미지가 별도 저장소에서 준비되어야 실제 경로를 바꿀 수 있다.

- IoT Rule이 전달하는 JSON 객체를 입력으로 처리한다. 현재 코드의 Kinesis `Records`·Base64 입력과 다르다.
- 차량 식별은 인증된 디바이스의 MQTT 토픽에서 얻는 값이 기준이다. 본문에 같은 이름의 필드가 있을 때의 충돌 처리도 입력 계약에 포함한다.
- `FIREHOSE_STREAM_NAME` 환경 변수로 대상 스트림을 받는다. 4단계 인프라 코드에서 서비스 함수와 CI 함수에 각자의 스트림 이름을 연결한다. 외부 이미지도 이 변수명을 사용해야 한다. 기존 `QUEUE_URL`, `PROCESSED_BUCKET`, `MAX_MESSAGE_BYTES`는 이전 경로 처리를 위해 유지한다.
- 새 IoT 입력 경로에서는 전처리 결과를 Firehose에 보내며 S3나 수집 SQS에 직접 중복 전송하지 않는다.
- Firehose 전송 실패를 정상 응답으로 삼키지 않는다. IoT 비동기 입력에서는 예외를 반환해야 Lambda의 함수 오류 재시도가 작동한다.
- 전환 기간에는 기존 Kinesis 입력과 기존 환경 변수도 지원한다. 기존 적체를 처리할 수 있는 이미지를 준비한 뒤 트리거를 전환한다.
- JSON 내부의 도메인 필드와 필드 선별 정책은 외부 저장소의 계약을 따른다. Java와 Python의 현재 출력 형식이 다르므로 어느 쪽이 실제 배포 이미지인지 확인하지 않고 새 스키마를 확정하지 않는다.

단말 메시지를 다시 받아도 동일하게 유지되는 이벤트 식별자가 필요하다. 기존 `stream ARN + Kinesis event ID`는 새 IoT 입력에 없다. 사용할 원본 식별자와 `idempotencyKey` 계산 방식은 별도로 진행하는 Lambda·소비자 작업에서 맞춰야 하며, 인프라 코드만으로 확정하지 않는다. 단말에 고유 식별자가 없다면 해시 방식의 중복 판정 범위와 서로 다른 이벤트를 합칠 위험을 함께 정한다. 매 호출 시 생성한 UUID나 Lambda 요청 ID를 재시도 중복 제거 키로 쓰지 않는다.

`PutRecord` 성공은 Firehose가 수신했다는 뜻이며 S3 저장 완료를 뜻하지 않는다. API 재전송은 중복 레코드를 만들 수 있으므로 객체 알림의 중복 제거와 별개로 레코드 단위 중복 방지가 필요하다. 배치 API를 선택하면 `FailedPutCount`와 개별 결과도 처리해야 한다. [PutRecord](https://docs.aws.amazon.com/firehose/latest/APIReference/API_PutRecord.html), [PutRecordBatch](https://docs.aws.amazon.com/firehose/latest/APIReference/API_PutRecordBatch.html)

서비스 함수에는 승인된 이미지 digest를 `processing_image_uri`로 전달한다. CI 함수의 기존 `ignore_changes = [image_uri]`를 유지해 Jenkins가 올린 후보 이미지를 Terraform이 덮어쓰지 않게 한다. 새 이미지를 빌드하는 경로와 Jenkins의 검사 기준은 외부 저장소 변경에 맞춘다.

## 5. S3에서 SQS로 전달하는 계약

5단계에서 `delivery/s3_notifications.tf`와 `delivery/sqs_policy.tf`에 연결 설정을 추가한다. 기존 버킷과 큐를 재사용하며 알림용으로 새 버킷·큐를 만들지 않는다.

- `s3_queue_notifications_enabled`: 서비스 알림 생성 여부. 루트·delivery 기본값은 `false`.
- `ci_s3_queue_notifications_enabled`: CI 알림 생성 여부. 루트·delivery 기본값은 `false`.
- 두 플래그를 독립적으로 적용하므로 CI 알림을 먼저 켜도 서비스 알림은 생성하지 않는다.
- 큐 정책은 알림 활성화와 별개로 두 환경 모두에 준비한다. 정책은 해당 환경 버킷의 ARN과 계정에서 오는 S3 전송만 허용한다.
- 루트 `s3_queue_notifications_enabled` 출력은 Terraform에서 관리하는 서비스·CI 알림 리소스의 생성 여부를 보여준다. 실제 파일 수신·처리 성공을 증명하는 지표는 아니다.

이미 생성한 알림의 플래그를 `true`에서 `false`로 바꾸면 이 모듈이 관리하는 버킷 알림 설정이 제거된다. 가공 데이터 버킷이나 큐를 삭제하는 것은 아니다. 현재는 어느 플래그도 켜지 않는다.

첫 적용 전 기존 큐의 수동 정책을 조회하고 필요한 다른 권한을 함께 반영해야 한다. 알림 활성화 전에는 기존 버킷 알림도 조회해야 한다. `aws_sqs_queue_policy`는 큐 정책 문서를 관리하고, S3 알림 설정 API는 버킷의 전체 알림 구성을 덮어쓰므로 기존 설정이 자동으로 병합된다고 가정하지 않는다. 현재 AWS의 수동 정책·알림은 확인하지 않았다. [S3 전송 권한](https://docs.aws.amazon.com/AmazonS3/latest/userguide/grant-destinations-permissions-to-s3.html), [Terraform 알림 리소스](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification)

- 이벤트: `s3:ObjectCreated:*`. 멀티파트 업로드 완료를 포함한다.
- 필터: `firehose/processed/` prefix만 대상으로 한다. 기존 `processed/`, `raw/`, `aws/lambda/`, `firehose-errors/`는 제외한다.
- 대상: 기존 서비스 Standard SQS와 CI Standard SQS. 같은 리전의 버킷·큐를 사용한다.
- 큐 정책: `s3.amazonaws.com`의 `sqs:SendMessage`를 허용하되 해당 버킷 ARN과 AWS 계정으로 제한한다.
- 버킷별 알림 설정은 Terraform 리소스 하나에서 관리한다. AWS에 다른 알림이 이미 있으면 함께 보존한다.

SQS 본문은 AWS S3 이벤트 JSON이며 차량 데이터 본문이 아니다. 소비자는 `Records`의 각 객체 정보를 읽고, URL 인코딩된 객체 키를 디코딩하고, S3에서 객체를 받아 GZIP을 해제한 다음 JSON Lines를 처리해야 한다. 객체 버전이 있으면 해당 버전을 읽는다. 설정 시 보내지는 `s3:TestEvent`도 구분한다. [S3 이벤트 본문](https://docs.aws.amazon.com/AmazonS3/latest/userguide/notification-content-structure.html)

S3 알림과 Standard SQS는 중복·순서 변경에 대비해야 한다. 객체는 버킷·키·버전 또는 객체 이벤트 식별값으로 구분하고, 객체 안의 각 데이터는 별도 이벤트 키로 중복 반영을 막는다. 소비자는 필요한 `s3:GetObject` 및 버전 조회 권한을 갖고, 파일 전체의 처리를 확정한 뒤 SQS 메시지를 삭제한다. [S3 이벤트 전달](https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventNotifications.html)

기존 서비스 큐는 14일 보관, 기본 visibility timeout 120초, 최대 수신 5회 후 DLQ 이동 설정을 유지한다. 파일 단위 처리로 바뀌므로 120초 내 완료가 안 되면 소비자가 visibility timeout을 연장해야 한다. CI 큐와 버킷 데이터는 기존 1일 보관 정책을 유지하며 장기 복구용으로 사용하지 않는다.

현재 작업공간에서 프라이빗 SQS 소비자 구현을 확인하지 못했다. 소비자 준비 전 서비스 큐에 새 형식의 알림을 흘리지 않는다. 전환 때는 구형 본문과 신형 알림을 모두 처리할 소비자를 먼저 준비하거나, 유입을 잠시 멈추고 기존 Kinesis·SQS 적체를 모두 처리한 후 새 형식을 시작한다.

## 6. 호출 권한과 실패 처리

- IoT Rule은 기존 서비스 함수만 호출한다. CI 함수에는 운영 MQTT 트리거를 연결하지 않는다.
- IoT 호출은 Lambda 리소스 정책으로 허용하며 해당 Rule ARN·계정으로 제한한다. Firehose 전달용 IAM 역할과 구분한다.
- 두 Lambda가 공유하는 기존 실행 역할에 두 Firehose 스트림의 쓰기 권한을 추가한다. 기존 S3·SQS·Kinesis 권한은 이전 경로의 처리 완료 전까지 유지한다.
- 공유 실행 역할을 유지하므로 서비스·CI 분리는 서로 다른 환경 변수와 스트림·버킷·큐에 의한 운영상 분리다. IAM으로 서로의 리소스 접근을 차단한 보안 격리는 아니다.
- Firehose의 실행 역할은 Lambda 실행 역할과 별도로 두고 목적지 버킷·정상 및 오류 prefix·로그에 필요한 권한만 부여한다.

2단계에서는 서비스·CI Firehose 각각의 역할에 해당 목적지 버킷의 조회·멀티파트 관리, 정상·오류 prefix의 객체 읽기·쓰기, 전용 로그 스트림의 `logs:PutLogEvents`만 허용했다. 4단계에서는 기존 공유 Lambda 실행 역할에 두 스트림의 `firehose:PutRecord`·`firehose:PutRecordBatch`를 추가하고, CI 실패 보관을 위해 CI 버킷 조회·쓰기 권한도 추가한다. [Firehose S3 목적지 권한](https://docs.aws.amazon.com/firehose/latest/dev/controlling-access.html)

IoT의 Lambda 호출은 비동기다. 4단계 코드의 함수 오류 재시도 횟수는 `2회`, 비동기 이벤트 최대 나이는 `21,600초(6시간)`다. 함수 오류 재시도 횟수를 스로틀링·서비스 오류에 대한 총 시도 횟수로 해석하지 않는다. Kinesis의 `batchItemFailures` 응답은 새 입력의 실패 신호로 사용할 수 없다. [IoT Lambda 호출](https://docs.aws.amazon.com/iot/latest/developerguide/lambda-rule-action.html), [비동기 오류 처리](https://docs.aws.amazon.com/lambda/latest/dg/invocation-async-error-handling.html)

서비스 함수의 비동기 최종 실패는 기존 raw 버킷에, CI 함수의 실패는 CI 버킷에 보관하는 안을 사용한다. Lambda가 정하는 `aws/lambda/async/` 경로는 수집 SQS 알림에서 제외한다. 실패 목적지 전달 자체가 실패하는 경우도 있으므로 `DestinationDeliveryFailures`를 관측한다. 기존 Kinesis 이벤트 소스 매핑의 실패 목적지와 새 비동기 호출 실패 목적지는 별도 설정이다. [비동기 실패 보관](https://docs.aws.amazon.com/lambda/latest/dg/invocation-async-retain-records.html)

IoT Rule에서 Lambda 서비스에 전달하지 못한 오류는 기존 IoT 오류 로그로 관측한다. 이 오류 로그를 원문 전체의 복구 저장소로 간주하지 않는다. 정상 수집 SQS와 소비자의 DLQ도 Lambda 호출 이전의 실패를 복구하지 못한다.

Kinesis 제거 후에는 현재의 24시간 스트림 재읽기 기능이 없어진다. Firehose도 S3 전달 장애 시 수신 후 24시간이 지나면 데이터를 더 이상 제공하지 않으므로 무기한 복구 저장소가 아니다. `firehose-errors/` 설정만으로 S3 장애 시 모든 데이터를 별도 보관한다고 가정하지 않는다. 실패 보관 파일의 재처리는 별도 절차다. [Firehose 수신 데이터 보관](https://docs.aws.amazon.com/firehose/latest/APIReference/API_PutRecord.html)

### IoT Rule의 서비스 Lambda 직접 호출

사용자 결정에 따라 최종 경로에 Kinesis는 두지 않는다. 기존 `aws_iot_topic_rule.telemetry`의 전송 액션을 서비스 Lambda 호출 하나로 고정하고, Kinesis·Lambda 선택 변수와 관련 출력·분기를 제거한다. 새 Rule이나 Lambda 함수를 생성하지 않으며, Rule의 Terraform 주소·AWS 이름·토픽 필터·SQL·오류 로그 경로는 유지한다. CI 함수는 운영 Rule에 연결하지 않는다.

Lambda 대상 ARN은 `module.processing.function_arn`에서 항상 받는다. 이 출력은 호출 권한과 비동기 실패 보관 설정의 준비를 기다린다. 호출 권한의 source ARN은 Rule 리소스를 참조하지 않는 `local.iot_rule_arn` 출력에서 얻으므로 모듈 사이 순환 의존을 피한다. ingestion 모듈을 단독 사용해도 동일 계정·리전의 유효한 Lambda 함수 ARN은 필수다.

`iot_rule_enabled`는 규칙을 켜고 끄는 설정일 뿐 전송 대상을 바꾸지 않는다. 비활성 상태에도 액션 정의는 Lambda로 고정된다.

- 활성 Rule에는 `s3_queue_notifications_enabled = true`가 필요하다. CI 알림 플래그는 이 조건에 포함하지 않는다.
- S3 알림 기본값이 false이므로, 현재 기본값만으로는 활성 Rule의 plan이 차단된다. 준비 단계에서는 `iot_rule_enabled = false`를 지정하고, 실제 활성화할 때 서비스 S3 알림도 함께 켠다.
- 실제 AWS 적용 전에 새 IoT 입력·Firehose 출력을 지원하는 이미지와 S3 객체 알림을 처리하는 소비자가 준비되어야 한다. 변수 검증이 외부 이미지·소비자의 호환성을 보장하지는 않는다.

실제 활성화 시 필요한 변수 조합은 다음과 같다. 현재 AWS에는 적용하지 않았다.

```hcl
iot_rule_enabled               = true
s3_queue_notifications_enabled = true
```

서비스 S3 알림을 먼저 준비한 뒤 활성 IoT 입력을 전환한다. 알림 활성화 전에 생성된 객체가 나중에 자동으로 소급 통지된다고 가정하지 않는다.

Kinesis Stream·Channel·기존 Lambda 이벤트 소스 매핑과 전용 권한·변수의 제거는 후속 정리 단계로 분리한다. 이번 Rule 수정에 해당 리소스 삭제를 섞지 않는다. 최종 구성에 Kinesis 선택지를 남기는 것은 아니다.

## 7. 단계별 변경과 커밋 경계

1. 이 설계 문서만 추가한다. 미확정 사항은 사용자와 외부 코드 담당자가 결정한다.
2. 기존 경로를 유지한 채 서비스·CI Firehose, 쓰기 역할, 로그, 출력값을 추가한다.
3. 사용자 측에서 별도 Lambda 저장소의 소스 수정·이미지 준비를 진행한다. 이 세션에서는 해당 작업 대신 다음 인프라 준비 단계로 진행한다. 새 입력·출력을 지원하는 이미지가 준비되기 전 실제 Rule 전환은 하지 않는다.
4. 기존 Lambda의 권한·환경 변수·이미지 연결, CI 연동, IoT 호출 권한과 비동기 실패 설정을 준비한다. 실제 Rule 대상은 아직 바꾸지 않는다.
5. S3 알림·SQS 정책을 준비한다. 서비스·CI 알림 기본값은 false로 두고, 서비스 소비자와 별도 Lambda 이미지 준비 이후에 각 환경을 활성화한다. 소비자 애플리케이션 코드는 이 세션에서 수정하지 않는다.
6. IoT Rule을 기존 서비스 Lambda 직접 호출로 고정한다. 이미지·소비자·S3 알림을 준비한 뒤 실제 활성화한다. 새 경로의 로그·알람 갱신과 기존 적체의 처리 완료 확인은 후속 작업이다.
7. 기존 Kinesis·Channel·이벤트 소스 매핑과 불필요한 설정만 제거한다. 버킷·과거 데이터·서비스 및 CI Lambda는 유지한다.

이미지 변경, 환경 변수 준비, Rule 전환은 Terraform의 한 번의 apply 안에서 순서가 보장된다고 가정하지 않는다. 전환 단계는 필요하면 여러 번의 apply로 나누며, 복구 시에는 호환 이미지·실패 보관 이벤트·처리 중인 데이터와 소비자 상태를 함께 고려한다.

각 단계는 사용자가 검토·커밋한 뒤 다음 단계로 넘어간다. 커밋했다고 AWS에 적용되는 것은 아니다.

모듈 구조 정리는 Lambda 연결 준비 커밋 `d4dc407` 다음의 별도 변경으로 진행한다. 이 변경에서는 리소스의 소유 모듈과 참조를 정리하며, IoT 전송 대상 전환이나 Kinesis·Channel 제거를 함께 진행하지 않는다.

## 8. 필요한 확인과 이번 단계의 한계

1단계에서는 문서의 리소스 주소와 설정을 로컬 코드 및 AWS 공식 문서와 대조했다. 2단계와 4단계에서는 추가·수정한 Terraform의 `fmt -check`와 `validate`만 수행했다. 모듈 구조 정리에서는 기존 processing mock 테스트 3개를 새 입력 구조로 조정해 실행하고, 이동한 리소스 정의와 `moved` 대응 관계도 대조했다. 5단계에서는 포맷·구성 검증 및 delivery 알림 mock 테스트 3개로 기본 비활성화·CI 단독 활성화·양쪽 활성화와 정상 prefix의 선택적 알림을 확인했다. IoT Rule 작업에서는 포맷·구성 검증, Lambda 직접 호출 mock 테스트 4개와 실제 루트 variables.tf의 전환 조건 3가지를 AWS provider·backend가 없는 임시 디렉토리에서 확인했다. 실제 AWS를 사용하는 테스트, Docker 빌드, AWS 대상 plan·apply, 실제 메시지 송신은 수행하지 않았다.

설치된 provider 스키마 조회와 모듈 초기화 중 원격 backend 인증 세션 만료를 확인했다. 일반 초기화는 인증 단계에서 완료하지 못했지만 로컬 모듈 등록 이후 구성 검증과 mock 테스트는 통과했다. 실제 AWS 계획은 확인하지 않았으며, apply 전 AWS에 다시 로그인하고 최신 plan으로 변경 범위를 확인해야 한다. 로컬 문법·참조 검증의 통과를 AWS 전달 성공이나 삭제·교체 없음의 증거로 삼지 않는다.

이후 필요성이 생기는 시점에 사용자에게 알릴 최소 확인은 다음과 같다.

- Terraform 코드 변경 시 `fmt -check`와 `validate`로 문법·참조 오류를 확인한다. 자동 테스트 추가·반복 실행은 별도로 합의한다.
- 실제 apply 전 최신 `terraform plan`에서 삭제·교체 대상을 확인한다. 특히 서비스·CI Lambda, S3·SQS의 의도하지 않은 삭제가 없어야 한다.
- 새 구조로 전환할 때 최소 한 건의 메시지가 S3 객체와 SQS 알림까지 도달하는지 확인한다. 건너뛰면 실제 연결 성공을 확인할 근거가 없다.
- 기존 경로를 제거하기 전 적체·실패 기록과 소비자 준비 상태를 확인한다. 경로 제거 전에 필요한 확인을 생략한 채 전환 완료라고 판단하지 않는다.

아직 확인하지 않은 항목은 실제 AWS 배포 이미지·드리프트·기존 알림 구성, 처리량과 지연 요구, 프라이빗 소비자 호환성이다. 설계 문서만으로 실제 데이터 무손실이나 리소스 무교체를 보장하지 않는다.
