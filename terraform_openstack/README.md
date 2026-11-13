# UBI OpenStack 리소스 가져오기

Horizon에 표시된 `ubi` 프로젝트의 Nova VM 9대와 Neutron 네트워크 3개, 서브넷 3개를 등록합니다. `ext-net`과 `ext-subnet`을 포함하므로 실행 계정에서 두 리소스를 조회할 수 있는지 확인하세요.

이번 범위는 VM·네트워크·서브넷입니다. Neutron 라우터·포트·Floating IP·보안 그룹과 Cinder 볼륨은 별도로 등록하지 않습니다. VM에 연결된 기존 설정은 유지한 상태로 인수하며, 해당 리소스까지 코드로 재생성하려면 의존 관계를 별도로 정의해야 합니다.

## 1. 인증 및 UUID 준비

OpenStack API에 접근할 수 있는 관리 머신에서 `ubi` 프로젝트 자격 증명을 설정합니다. 기존 OpenRC를 불러오거나, `clouds.yaml` 프로필을 사용하는 경우 `OS_CLOUD`를 설정합니다. 자격 증명은 이 폴더에 복사하지 마세요.

```bash
cd terraform_openstack
cp import.tfvars.example import.tfvars
```

Horizon 상세 화면에서 각 리소스의 ID를 복사해 `import.tfvars`의 빈 값 15개를 채웁니다. OpenStack CLI가 설치되어 있으면 아래 조회 명령으로도 확인할 수 있습니다. VM은 IP나 이름, 서브넷은 CIDR과 부모 네트워크도 함께 대조하세요.

```bash
openstack server list
openstack network list
openstack subnet list
```

## 2. 현재 설정으로 리소스 코드 생성

기본 백엔드는 실행 머신의 로컬 파일입니다. 내부 원격 백엔드를 쓸 계획이면 아래 명령 전에 구성하세요. 로컬 state를 사용하는 경우 초기화 대상인 OpenStack 호스트 밖에 저장하고 별도로 백업하세요.

```bash
terraform init
terraform plan -var-file=import.tfvars -generate-config-out=generated_resources.tf
```

`generated_resources.tf`에는 공급자가 조회한 속성이 들어갑니다. 생성 기능은 실험적이며 VM 부팅 디스크나 포트 연결처럼 조회 결과만으로 확정할 수 없는 설정이 있을 수 있습니다. 생성 중 오류가 나도 파일이 만들어질 수 있으니 오류 메시지와 생성 코드를 함께 검토하세요. 파일이 생성된 뒤에는 같은 경로로 다시 생성하는 대신 파일을 수정하고 일반 `plan`을 실행합니다.

## 3. 변경 없이 등록

```bash
terraform plan -var-file=import.tfvars -out=import.tfplan
```

**`15 to import, 0 to add, 0 to change, 0 to destroy`일 때만** 아래 명령을 실행하세요. 변경이나 교체가 표시되면 현재 설정과 UUID를 대조하고 생성된 코드를 수정한 뒤 다시 계획합니다.

```bash
terraform apply import.tfplan
terraform state list
terraform plan -var-file=import.tfvars
```

마지막 계획에서 `No changes`를 확인합니다. 등록을 마치면 `imports.tf`와 `variables.tf`의 import 전용 구성을 제거할 수 있습니다. 생성된 리소스 코드와 state는 보존하세요. 전체 초기화 후 신규 배포에 사용하려면 생성 코드의 기존 네트워크·포트 ID 같은 고정 참조를 검토하고, 리소스 간 참조나 입력값으로 바꿔야 합니다.
