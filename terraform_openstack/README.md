# OpenStack Terraform 실행

## 기존 state가 있는 환경

현재 리소스를 등록한 `os-cmp1`의 `terraform_openstack` 폴더에서 실행합니다.
기존 `terraform.tfstate`와 백업을 보존하세요. 코드만 새로 내려받는다고 기존 state가 복원되지는 않습니다.

OpenRC를 불러오거나 `OS_CLOUD`를 설정한 뒤 다음 명령으로 확인합니다.

```bash
terraform init
terraform plan -out=lookup.tfplan
```

기존 UUID 입력 변수는 이름 기반 조회로 대체했으므로 `-var-file=import.tfvars`는 더 이상 사용하지 않습니다.
`import.tfvars`는 보관해도 되지만, 이전 이름의 변수를 전달하면 미선언 변수 경고가 발생합니다.
기존 리소스 주소와 모듈 내부 설정은 유지했습니다. 이 환경에서는 생성·수정·삭제가 없는지 먼저 확인하세요.
그 경우에만 저장한 계획을 적용합니다.

```bash
terraform apply lookup.tfplan
```

조회용 data 항목이 state에 추가될 수 있지만, 기존 VM이나 네트워크를 다시 import하는 작업은 아닙니다.
이전 코드에서 만든 저장 계획은 적용하지 말고, 현재 코드로 새 계획을 만드세요.

## UUID를 조회하는 방식

- `lookups.tf`: 프로젝트·이미지·Flavor를 이름으로 조회하여 운영 설정에 전달합니다.
- `imports.tf`: 인수할 네트워크·서브넷·포트를 조회하고, 포트의 `device_id`에서 VM UUID를 얻습니다.
- `main.tf`, `network.tf`: 위 조회 결과를 기존 compute/network 모듈에 전달합니다.
- `variables.tf`: 이름 입력과 `import_existing` 스위치를 정의합니다. 기본값은 현재 환경의 이름입니다.

프로젝트 기본값은 ID가 `default`인 기본 도메인의 `admin`, `ubi`입니다.
Keystone 프로젝트 조회, Glance 이미지 조회, Nova Flavor 조회 권한이 필요합니다.
기존 Neutron 조회 권한에 더해 이 권한들이 있는 인증 계정을 사용하세요.
다른 이름을 사용하는 환경에서는 UUID 대신 `project_names`, `ubuntu_image_name`, `flavor_names`를 별도 tfvars로 전달할 수 있습니다.
다른 도메인을 사용한다면 `project_domain_id`도 지정합니다.

동명 리소스가 여러 개 조회되면 임의로 선택하지 않고 오류를 해결해야 합니다.
이미지는 `most_recent=false`로 두어 같은 이름의 새 이미지를 자동 선택하지 않습니다.
이름이 유일하더라도 기존 이미지나 Flavor와 다른 UUID를 조회하면 VM 수정·교체가 계획될 수 있으므로 plan을 확인하세요.
프로젝트·이미지·Flavor 및 기존 보안 그룹은 조회만 하며, 해당 자원 자체를 생성하는 코드는 아닙니다.

## 기존 리소스를 처음 인수할 때

기존 state가 있는 현재 환경에서는 이 절차가 필요하지 않습니다.
같은 리소스를 관리하는 다른 state나 CI 실행이 없는지 먼저 확인하고, 대상 리소스가 아직 등록되지 않은 경우에만 사용합니다.

```bash
terraform plan -var='import_existing=true' -out=import-discovered.tfplan
```

이 모드에서는 네트워크 3개, 서브넷 3개, 포트 10개와 그 포트에 연결된 VM 10개의 UUID를 조회합니다.
네트워크는 프로젝트, 서브넷은 프로젝트와 네트워크, 포트는 프로젝트와 네트워크로 조회 범위를 제한합니다.
포트가 VM에 연결되지 않았거나 연결 VM의 이름이 예상과 다르면 계획을 중단합니다.
누락·중복 조회나 연결 불일치를 해결하기 전에는 apply하지 마세요.

state가 비어 있고 모든 기존 리소스가 코드와 일치한다면 기대 결과는 다음과 같습니다.

```text
Plan: 26 to import, 0 to add, 0 to change, 0 to destroy.
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
전체 인프라를 빈 OpenStack 환경에 재구축하는 설정도 아닙니다. 기존 프로젝트·이미지·Flavor·보안 그룹 등이 필요합니다.
Swift backend 설정과 state 이전은 이번 변경에 포함하지 않았습니다.
