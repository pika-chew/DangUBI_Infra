# OpenStack Terraform 실행

## 운영용 Swift 컨테이너 준비

Terraform은 전용 Swift 컨테이너의 `openstack/terraform.tfstate`에 현재 state를 저장합니다.
Swift 버전 관리와 별도 `.backup` 객체는 사용하지 않으므로, 이전 버전은 자동으로 보존되지 않습니다.
Swift S3 키는 `AWS_ACCESS_KEY_ID`와 `AWS_SECRET_ACCESS_KEY` 환경변수로 전달합니다.

아래 블록 전체를 Mac 터미널에 붙여넣고, 입력란에 앞서 테스트에 성공한 Vault의 Swift 키를 넣습니다.
키는 화면에 표시되지 않으며 이 블록에서만 사용합니다. 아래 예시는 `ubi-openstack-tfstate`를 사용합니다.
기존 데이터나 테스트 컨테이너는 재사용하지 않습니다. 이름이 이미 사용 중이면 별도 이름을 선택하고 이후 명령에도 같은 이름을 사용합니다.

```zsh
(
set +x
set -e
unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
export AWS_CONFIG_FILE=/dev/null AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_PAGER=""
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required AWS_RESPONSE_CHECKSUM_VALIDATION=when_required

IFS= read -rs 'AWS_ACCESS_KEY_ID?Vault의 Swift access_key: '
printf '\n'
IFS= read -rs 'AWS_SECRET_ACCESS_KEY?Vault의 Swift secret_key: '
printf '\n'
: "${AWS_ACCESS_KEY_ID:?Swift access_key를 입력하세요}"
: "${AWS_SECRET_ACCESS_KEY:?Swift secret_key를 입력하세요}"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

swift_s3() {
  aws --endpoint-url http://10.10.0.10:8081 --region us-east-1 s3api "$@"
}

bucket=ubi-openstack-tfstate
existing=$(swift_s3 list-buckets --query "Buckets[?Name=='$bucket'].Name | [0]" --output text)
if [ "$existing" != None ]; then
  printf '이미 사용 중인 컨테이너 이름입니다: %s\n' "$bucket" >&2
  exit 1
fi

swift_s3 create-bucket --bucket "$bucket"
swift_s3 list-objects-v2 --bucket "$bucket" --query KeyCount --output text
)
```

목록 조회 결과가 `0`인지 확인합니다. 운영 state에는 민감 정보가 들어갈 수 있으므로 컨테이너 접근 권한과 내부 네트워크의 HTTP 사용 범위도 확인합니다.

## 기존 로컬 state 이전

이전 중에는 같은 state를 사용하는 작업을 중단합니다. 기존 리소스를 등록한 `os-cmp1`의 작업 폴더에서,
backend 변경 코드를 받기 전에 `terraform state list`로 현재 리소스 목록을 확인합니다.
코드를 받은 뒤 같은 폴더에서 Swift 키를 설정하고 아래 명령으로 기존 state를 옮깁니다.
로컬 `terraform.tfstate`가 없거나 대상 컨테이너가 비어 있지 않으면 중단하고 실제 위치를 확인합니다.

```bash
cd ~/DangUBI_Infra/terraform_openstack
test -s terraform.tfstate && \
  terraform init -migrate-state -backend-config="bucket=ubi-openstack-tfstate"
```

Terraform이 표시한 이전 대상이 예상한 Swift 컨테이너와 일치할 때만 확인합니다. `-reconfigure`는 기존 state를 옮기지 않습니다.
이전 후 `terraform state list`가 이전 목록과 일치하는지 확인하고, OpenRC 또는 `OS_CLOUD` 인증을 준비한 뒤 `terraform plan`의 `No changes`를 확인합니다.
기존 파일을 검증 전에 삭제하지 마세요.

## 이전 후 일반 작업

새 작업 폴더에서는 Swift 키를 설정하고 같은 컨테이너 이름으로 초기화합니다. 인프라 변경을 계획하려면 OpenRC를 불러오거나 `OS_CLOUD`를 설정합니다.

```bash
terraform init -backend-config="bucket=ubi-openstack-tfstate"
terraform plan -out=lookup.tfplan
```

기존 UUID 입력 변수는 이름 기반 조회로 대체했으므로 `-var-file=import.tfvars`는 더 이상 사용하지 않습니다.
`import.tfvars`는 보관해도 되지만, 이전 이름의 변수를 전달하면 미선언 변수 경고가 발생합니다.
`No changes`라면 적용할 필요가 없습니다. 변경이 있다면 계획이 의도한 생성·수정·삭제만 포함하는지 확인한 뒤 적용합니다.

```bash
terraform apply lookup.tfplan
```

조회용 data 항목이 state에 추가될 수 있지만, 기존 VM이나 네트워크를 다시 import하는 작업은 아닙니다.
이전 코드에서 만든 저장 계획은 적용하지 말고, 현재 코드로 새 계획을 만드세요.

## UUID를 조회하는 방식

- `lookups.tf`: 프로젝트·이미지·Flavor를 이름으로 조회하여 운영 설정에 전달합니다.
- `imports.tf`: 기존 Neutron 리소스를 조회하고 VM 포트의 `device_id`에서 VM UUID를 얻습니다. 보안 그룹 규칙 UUID는 인수용 파일에서 받습니다.
- `main.tf`, `network.tf`: 조회한 프로젝트·이미지·Flavor와 관리 포트 참조를 compute/network 모듈에 전달합니다.
- `variables.tf`: 이름 입력과 `import_existing` 스위치를 정의합니다. 기본값은 현재 환경의 이름입니다.

프로젝트 기본값은 ID가 `default`인 기본 도메인의 `admin`, `ubi`입니다.
Keystone 프로젝트 조회, Glance 이미지 조회, Nova Flavor 조회 권한이 필요합니다.
기존 Neutron 조회 권한에 더해 이 권한들이 있는 인증 계정을 사용하세요.
다른 이름을 사용하는 환경에서는 UUID 대신 `project_names`, `ubuntu_image_name`, `flavor_names`를 별도 tfvars로 전달할 수 있습니다.
다른 도메인을 사용한다면 `project_domain_id`도 지정합니다.

동명 리소스가 여러 개 조회되면 임의로 선택하지 않고 오류를 해결해야 합니다.
이미지는 `most_recent=false`로 두어 같은 이름의 새 이미지를 자동 선택하지 않습니다.
이름이 유일하더라도 기존 이미지나 Flavor와 다른 UUID를 조회하면 VM 수정·교체가 계획될 수 있으므로 plan을 확인하세요.
프로젝트·이미지·Flavor와 Neutron이 자동 생성한 `default` 보안 그룹은 `data`로 조회합니다.
VM은 네트워크 모듈에서 관리하는 포트 UUID를 사용하며, 사용자 정의 보안 그룹은 포트에서 참조합니다.
기존 VM의 state에 포트 UUID가 비어 있어도 연결을 교체하지 않으며, Nova가 반환한 MAC으로 연결을 검증합니다.

## 기존 리소스를 처음 인수할 때

기존 state가 있는 현재 환경에서는 이 절차가 필요하지 않습니다.
같은 리소스를 관리하는 다른 state나 CI 실행이 없는지 먼저 확인하고, 대상 리소스가 아직 등록되지 않은 경우에만 사용합니다.
보안 그룹 규칙도 처음 등록한다면 Horizon에서 확인한 UUID를 `security-group-rules.import.tfvars`의 `security_group_rule_import_ids`에 넣습니다.

```bash
terraform plan -var='import_existing=true' \
  -var-file=security-group-rules.import.tfvars \
  -out=import-discovered.tfplan
```

이 모드에서는 네트워크·서브넷, 라우터와 인터페이스, VM·VIP 포트, Floating IP, 사용자 정의 보안 그룹을 조회합니다.
VM UUID는 VM 포트의 연결 정보에서, 보안 규칙 UUID는 인수용 파일에서 얻습니다.
네트워크는 프로젝트, 서브넷은 프로젝트와 네트워크, 포트는 프로젝트와 네트워크로 조회 범위를 제한합니다.
포트가 VM에 연결되지 않았거나 연결 VM의 이름이 예상과 다르면 계획을 중단합니다.
누락·중복 조회나 연결 불일치를 해결하기 전에는 apply하지 마세요.

state가 비어 있고 모든 기존 리소스가 코드와 일치한다면 기대 결과는 다음과 같습니다.

```text
Plan: 91 to import, 0 to add, 0 to change, 0 to destroy.
```

부분적으로 등록된 state라면 import 개수는 미등록 리소스 수만큼 줄어듭니다.
계획을 검토한 뒤 적용하고, 이후에는 기본값 `import_existing=false`로 운영합니다.

```bash
terraform apply import-discovered.tfplan
terraform plan
```

## 주의 사항

`import_existing=false`는 import용 조회를 끄는 옵션이며, 생성을 막는 옵션은 아닙니다.
운영 state가 없는 폴더에서 기본 plan을 실행하면 기존 리소스와 같은 이름의 자원을 새로 생성하려고 계획할 수 있습니다.
새 환경에서 실행하려면 기존 프로젝트·이미지·Flavor·Nova 키페어 등이 필요합니다.
