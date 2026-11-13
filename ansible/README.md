# DangUBI Ansible

Ansible로 OpenStack VM 위에 올라가는 인프라를 구축/관리합니다.

- Ansible Control Node: jenkins-vm

---
<br>

## Control node setup

Ansible을 설치하고, 이 디렉토리를 통해 플레이북 실행

```bash
python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate
pip install ansible
ansible-galaxy collection install -r collections/requirements.yml

ansible all -m ping
```

---
<br>

## Jenkins setup

```bash
ansible-playbook playbooks/jenkins-docker.yml
# Docker 그룹 권한 적용을 위해 jenkins-vm에 다시 로그인
ansible-playbook playbooks/jenkins.yml
```
`jenkins-docker.yml`: Docker 공식 APT 저장소로 Docker Engine, Compose 플러그인 설치, arm64 이미지 빌드용 QEMU 에뮬레이션(`qemu-user-static`) 설치
`jenkins.yml`: `/opt/jenkins`에서 커스텀 이미지를 빌드하고 Docker Compose로 Jenkins 실행

- 접속: `http://<jenkins-vm 주소>:8080`
- Jenkins 홈: `/var/lib/jenkins` (Cinder 볼륨 마운트 경로, 컨테이너의 `/var/jenkins_home`에 bind mount)
- 이미지 태그, MTU, HTTP 타임아웃: `roles/jenkins/defaults/main.yml`
- 플러그인 목록: `roles/jenkins/files/plugins.txt`
  (Dockerfile/plugins.txt를 바꾸면 `jenkins_image` 태그 끝 숫자를 올려 재빌드)

### 컨테이너 구성

- 이미지: `jenkins/jenkins:lts-jdk21` + docker CLI + 플러그인 사전 설치 (`roles/jenkins/files/Dockerfile`)
- Docker 빌드: 호스트의 `/var/run/docker.sock`을 마운트하고 docker 그룹 GID를 컨테이너에 추가해 호스트 데몬으로 이미지 빌드/푸시
- 네트워크: 컨테이너 네트워크 MTU를 `jenkins_docker_mtu`(기본 1450)로 맞춤. VM NIC MTU보다 크면 HTTPS 연결이 멈출 수 있음
- 재시작 정책 `unless-stopped`, `/login` 헬스체크, 타임존 `Asia/Seoul`

### 초기 admin 비밀번호

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

---
<br>

## Observability setup

모니터링 VM(`observability-vm`)에 관측 백엔드를 구축합니다.

- 주소: Floating IP `10.20.0.140` / 사설 IP `172.16.20.20`
- Ansible은 Floating IP로 접속 (`inventory/hosts.yml`의 `monitoring` 그룹)
- 저장소 데이터는 Cinder 볼륨 없이 인스턴스 루트 디스크(120GB)에 저장

```bash
# 최초 1회: jenkins-vm에서 SSH 접속해 host key 등록, sudo 확인
ssh ubuntu@10.20.0.140 'sudo -n true && echo sudo-ok'

ansible monitoring -m ping
ansible-playbook playbooks/monitoring-docker.yml
```
`monitoring-docker.yml`: `docker` 롤로 Docker Engine, Compose 플러그인 설치. 이미지를 빌드하지 않으므로 QEMU 에뮬레이션은 설치하지 않음(`docker_arm64_emulation: false`)

### Prometheus · Alertmanager · Grafana

```bash
# 최초 1회: 비밀값을 Vault로 암호화해 저장
ansible-vault create inventory/group_vars/monitoring/vault.yml
#   vault_grafana_admin_password: <비밀번호>
#   vault_alertmanager_slack_webhook_url: <Slack Incoming Webhook URL>

ansible-playbook playbooks/monitoring.yml --ask-vault-pass
```
`monitoring.yml`: `/opt/monitoring`에 설정 파일과 `docker-compose.yml`을 만들고 Docker Compose로 실행

| 서비스 | 포트 | 데이터 경로 |
|---|---|---|
| Prometheus | 9090 | `/var/lib/monitoring/prometheus` |
| Alertmanager | 9093 | `/var/lib/monitoring/alertmanager` |
| Grafana | 3000 | `/var/lib/monitoring/grafana` |

- 이미지 버전, 포트, 보관 기간(30일 / 40GB), MTU: `roles/monitoring/defaults/main.yml`
- 알림 규칙: `roles/monitoring/files/rules/` (Jinja 렌더링 없이 복사)
  - `base.yml`: Watchdog, TargetDown
  - `node.yml`: 노드 디스크·메모리, Alloy 데이터 끊김 (물리 노드 + K8s 노드 공통)
  - `kubernetes.yml`: 노드 NotReady, Pod·Deployment·Job 상태, etcd, API 서버, CoreDNS
  - 배포 전 문법 검사: `promtool check rules` (prom/prometheus 이미지에 포함)
- Grafana 데이터소스(Prometheus, Alertmanager): `roles/monitoring/files/grafana/provisioning/` 로 자동 등록
- Prometheus는 `--web.enable-remote-write-receiver`로 Alloy의 remote_write를 받음
- Alertmanager는 모든 알림을 Slack으로 보낸다(해결 알림 포함). Watchdog만 `null`로 버리며, 이후 외부 하트비트로 연결
- Alertmanager 설정 검사: 모니터링 VM에서 `docker exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml`
- 설정 파일이 바뀌면 해당 컨테이너만 재시작(handler)
- Grafana 관리자 비밀번호는 Grafana DB가 처음 만들어질 때만 적용됨

### Alloy

모니터링 VM(자기 감시)과 OpenStack 물리 노드에 Alloy를 설치합니다.

| 그룹 | 호스트 | `cluster` 라벨 | 전송 주소 |
|---|---|---|---|
| `monitoring` | observability-vm | `observability-vm` | `localhost:9090` |
| `openstack_nodes` | os-ctl1~3, os-cmp1 | `openstack` | `10.20.0.140:9090` (같은 내부망이라 직접 전송) |

```bash
# 최초 1회: jenkins-vm의 SSH 키를 물리 노드에 등록
ssh-copy-id pika1@10.20.0.2   # pika2@10.20.0.3, pika3@10.20.0.4, hong@10.20.0.5도 동일

# 물리 노드는 sudo 비밀번호가 필요하므로 --ask-become-pass
ansible-playbook playbooks/alloy.yml --limit openstack_nodes --ask-become-pass
ansible-playbook playbooks/alloy.yml --limit monitoring --ask-vault-pass
```
`alloy.yml`: Grafana 공식 APT 저장소로 Alloy를 설치하고 systemd 서비스로 실행

- 수집: 호스트 메트릭(`prometheus.exporter.unix`), Alloy 자신의 상태(`prometheus.exporter.self`)
- 전송: `alloy_remote_write_url`로 remote write, 모든 메트릭에 `env`·`cluster` 라벨 추가
- 그룹별 설정(`alloy_cluster`, `alloy_remote_write_url`): `inventory/group_vars/<그룹>/vars.yml`
- 설정 파일: `/etc/alloy/config.alloy` (배포 전 `alloy fmt`로 문법 검사)
- 외부 exporter 수집: 호스트별 `alloy_scrape_jobs`(`inventory/hosts.yml`)에 지정한 주소를 scrape. `instance` 라벨은 호스트명
  - OpenStack 노드는 Kolla-Ansible이 띄운 exporter를 수집 (아래 표)
- 네트워크 메트릭에서 가상 인터페이스(docker veth, OpenStack tap/qvo/qvb/qbr) 제외: `alloy_netdev_device_exclude`
- 디버깅 UI: `127.0.0.1:12345` (외부 미노출, `ssh -L 12345:localhost:12345`로 접속)

### Kolla-Ansible exporter (OpenStack 서비스 메트릭)

OpenStack 노드의 `/etc/kolla/globals.yml`에서 Prometheus 서버·Alertmanager·node_exporter 등은 끄고 exporter만 켭니다. exporter는 Kolla 관리망(`10.10.0.x`)에만 열리므로 각 노드의 Alloy가 자기 노드의 exporter를 수집합니다.

| job | 포트 | 노드 | 내용 |
|---|---|---|---|
| `mysqld` | 9104 | os-ctl1~3 | MariaDB(Galera) 연결·쿼리·동기화 상태 |
| `rabbitmq` | 15692 | os-ctl1~3 | RabbitMQ 내장 플러그인. 큐 적체, 연결 수 |
| `libvirt` | 9177 | os-ctl1~3, os-cmp1 | VM별 CPU·메모리·디스크 |
| `openstack` | 9198 | os-ctl1 | OpenStack API 상태, VM·자원 현황. 60초 간격 |

```bash
# OpenStack 노드(os-ctl1, ~/kolla-deploy)에서. Kolla 인벤토리 [monitoring]에 os-ctl1 추가 후
kolla-ansible deploy -i multinode -t prometheus --ask-become-pass
kolla-ansible reconfigure -i multinode -t rabbitmq --ask-become-pass   # RabbitMQ 재시작 주의
```

---
<br>

## Kubernetes setup

OpenStack VM 위에 kubeadm + containerd로 단일 Kubernetes 클러스터를 구성합니다.
role은 OS·containerd 준비, 첫 Control Plane의 init, 나머지 Control Plane과 Worker의
순차 join, OpenStack CCM·Calico 설치와 네트워크 검증을 수행합니다.
VM 생성과 SSH/sudo 접속은 확인했으며, 실제 클러스터 구축은 검증 전입니다.
빈 설정값으로는 설치를 시작하지 않습니다.

- Control Plane VM 3대: ctl1·ctl2·ctl3에 각각 배치, stacked etcd 구성
- Worker VM 4대: ctl1·ctl2·ctl3·cmp1에 각각 배치
- ctl1·ctl2·ctl3·cmp1은 물리 호스트이며, Ansible 접속 대상은 그 위의 VM
- 실행 노드: 기존 jenkins-vm. Jenkins는 해당 VM의 Docker Compose 환경을 유지
- Roles: `roles/kubernetes/` 아래 기능별 role
- Playbook: `playbooks/kubernetes/site.yml`
- Inventory: 기존 `inventory/hosts.yml`의 `kubernetes` 그룹
- 공통 설정: `inventory/group_vars/kubernetes/vars.yml`
- 대상 OS: Ubuntu 24.04, systemd, IPv4. 다른 OS와 IPv6는 현재 지원 범위에 포함하지 않음

### Role 구조와 실행 순서

`site.yml`에는 대상 호스트·실행 순서·role 호출만 두고, 검증과 설치 구현은 각 role에 둡니다.
기존 Docker·Jenkins·모니터링 role과 구분하기 위해 Kubernetes 전용 role은 모두
`roles/kubernetes/` 아래에 보관하며 `kubernetes/common`처럼 경로로 호출합니다.

```text
roles/kubernetes/
├── inventory/      # 실행 노드에서 VM 7대의 구성과 그룹 중복 검사
├── preflight/      # 전체 배치·IP와 각 VM의 OS·버전·NIC·기존 설치 상태 검사
├── common/         # swap 비활성화, 커널 모듈·sysctl·설정 디렉터리 준비
├── packages/       # APT 저장소 등록, 지정 버전 패키지 설치·hold
├── containerd/     # CRI·systemd cgroup 설정과 서비스 시작
├── api_lb/         # 선택적으로 CP의 HAProxy·Keepalived 구성
├── control_plane/  # 첫 CP의 kubeadm init과 API 응답 확인
├── join/           # 추가 CP와 Worker 가입, 임시 자격증명 정리
├── ccm/            # OpenStack 노드 연동, hostNetwork로 CNI보다 먼저 시작
├── calico/         # Tigera Operator와 VXLAN Installation 구성
├── verify/         # 7대 Ready·cloud identity·Worker Pod 통신과 DNS 검사
├── argocd/         # 구축 완료 후 별도 플레이북으로 Argo CD 설치
└── tests/          # VM에 접속하지 않는 로컬 검증
```

실행 순서는 inventory 검증 → 전체 노드의 preflight/common/packages/containerd →
CP의 API LB → 첫 CP 초기화 → 추가 CP 순차 가입 → Worker 순차 가입 → CCM → Calico → 결과 확인입니다.
첫 CP는 inventory의 `kubernetes_control_plane` 그룹에서 첫 번째로 등록한 VM입니다.
추가 CP play는 `[1:]`로 첫 CP를 제외하며, `serial: 1`로 etcd 멤버를 한 대씩 추가합니다.
템플릿과 handler는 사용하는 role 안에 두고, 공통 입력값과 기본 설정은
`inventory/group_vars/kubernetes/vars.yml` 한 곳에서 관리합니다.

### Inventory와 실행 전 확인

Control Plane 3대와 Worker 4대의 실제 IP·물리 호스트 배치를 등록했습니다.
사설망 NIC는 7대 모두 `ens3`, NIC MTU는 `1450`으로 확인했습니다.
`ansible_host`에는 jenkins-vm에서 SSH로 접근할 주소를 지정합니다.
SSH 접속 IP와 Kubernetes 내부 통신 IP는 다를 수 있습니다.
각 VM에 `kubernetes_node_ip`, `kubernetes_physical_host`, `kubernetes_interface`,
`kubernetes_nic_mtu`도 지정합니다. 사설 IP 중복·물리 호스트 분산·실제 NIC IP/MTU를 검사합니다.

기존 `all.vars`의 Ubuntu 계정과 Python 경로를 상속하므로 실제 VM 이미지와 일치하는지 확인합니다.
`ansible_connection: local`은 기존 jenkins-vm에만 적용되며, Kubernetes VM에는 SSH로 접속합니다.
jenkins-vm의 SSH 키와 대상 VM의 sudo 권한, host key 등록이 필요합니다.

아래 명령은 jenkins-vm의 `ansible` 디렉터리에서 실행합니다.
`ansible.cfg`가 기존 inventory를 지정하므로 별도의 `-i` 옵션은 필요 없습니다.

```bash
ansible-inventory --graph
ansible-playbook playbooks/kubernetes/site.yml --syntax-check --ask-vault-pass

# VM을 inventory에 등록하고 SSH 접속을 준비한 후 실행
ansible kubernetes -m ping --ask-vault-pass
```

`ping` 모듈은 ICMP ping이 아니라 SSH 접속과 대상 Python 실행을 확인합니다.
SSH/Python 실행과 sudo 권한은 7대에서 확인했으며, 클러스터 설치·통신 검증은 별도로 수행합니다.

### 비공개 변수와 Vault

일반 설정은 `inventory/group_vars/kubernetes/vars.yml`에 두고, 다음 네 값만
같은 디렉터리의 `vault.yml`에 `vault_` 접두어로 저장합니다.

- `vault_ansible_ssh_private_key_file`: Jenkins VM에서 사용하는 SSH 개인키 경로
- `vault_kubernetes_node_cidr`: 실제 VM 사설망 CIDR
- `vault_kubernetes_pod_cidr`: Calico IPPool과 kubeadm에서 사용할 Pod CIDR
- `vault_kubernetes_service_cidr`: 선택한 `/16` Service CIDR

`vault.yml.example`은 값이 비어 있는 변수 이름 안내이며, 자동 로딩 대상이 아닙니다.
새 환경에 암호화된 `vault.yml`이 없다면 최초 1회 생성합니다. 기존 파일이 있으면 다시 만들지 않습니다.
기존 `group_vars/kubernetes.yml`과 새 디렉터리를 동시에 유지하지 않습니다.
기존 파일은 삭제하고 디렉터리 구조로 옮겼으므로 브랜치 업데이트 시 삭제도 함께 반영합니다.

```bash
# 비밀번호는 로컬 프롬프트에서 직접 입력하고, 편집기에 네 변수를 작성합니다.
ansible-vault create inventory/group_vars/kubernetes/vault.yml

# 이후 수정도 복호화된 평문 파일을 따로 만들지 않고 수행합니다.
ansible-vault edit inventory/group_vars/kubernetes/vault.yml
```

파일 첫 줄이 `$ANSIBLE_VAULT;`로 시작하는지 확인한 뒤 암호화된 파일만 커밋합니다.
Vault 비밀번호와 SSH 개인키 자체는 저장소에 넣지 않습니다.
Vault 파일을 참조하는 Kubernetes 명령에는 `--ask-vault-pass`를 사용합니다.
실제 변수 내용이 출력되는 `ansible-inventory --host/--list`, debug, diff 결과를 공개하지 않습니다.
이 범위는 지정한 네 변수만 보호합니다. inventory의 노드 IP·물리 배치와 과거 Git 기록은 그대로입니다.

### 구축 전 확정할 항목

- VM의 OS·사양·사설 IP·네트워크 인터페이스, Kubernetes/containerd 버전
- CNI, Pod CIDR, Service CIDR, VM NIC MTU와 CNI의 MTU
- HAProxy·Keepalived 설치 위치, API VIP/FIP, 인증서, 보안그룹과 VIP 전환
- OpenStack CCM의 노드 연동 사용, Service·Route 컨트롤러 비활성화 설정
- CCM용 Application Credential과 CP에서 Keystone·Nova·Neutron API 접근

Cinder·local PV용 디스크·마운트·CSI 설정은 후속 스토리지 구성 단계에서 준비합니다.

`inventory/group_vars/kubernetes/vars.yml`의 빈 값을 채운 뒤 실행합니다.
Kubernetes는 `kubernetes_version`과 APT의 정확한 `kubernetes_package_version`을 함께 지정하고,
containerd도 `kubernetes_containerd_package_version`에 저장소의 정확한 `containerd.io` 버전을 지정합니다.
role은 Docker Engine을 설치하지 않습니다. containerd 1.x/2.x에 맞춰 설정 스키마를 구분하며,
Kubernetes 패키지는 kubeadm v1beta4 설정을 지원하는 1.31 이상을 전제로 합니다.
이 하한은 해당 버전의 운영 지원 또는 최신 버전과의 호환성을 보장한다는 뜻은 아닙니다.
현재 addon 사전 검증은 Kubernetes 1.36·Calico v3.33.0·CCM v1.36.0 조합으로 제한합니다.
버전 변경은 CRD·설정·공식 호환 범위를 다시 검토한 뒤 별도 업그레이드 절차로 진행합니다.

현재 선택한 초기 구축 조합은 Kubernetes `1.36.5`(APT `1.36.5-1.1`),
containerd `2.3.6` LTS(APT `2.3.6-1~ubuntu.24.04~noble`), Calico `v3.33.0`, OpenStack CCM `v1.36.0`입니다.
Calico 3.33의 테스트 범위에 Kubernetes 1.36이 포함되고, containerd 2.3은 Kubernetes 1.36의
권장 호환 범위에 포함됩니다. 이는 공식 문서상의 호환 범위이며 실제 VM 설치·통신 검증은 아직 수행하지 않았습니다.
Kubernetes 패키지는 amd64/arm64 등, 위 containerd 패키지는 Ubuntu 24.04 amd64 저장소에서 존재를 확인했습니다.

Calico role은 일반 Linux `Iptables` 데이터플레인, kube-proxy 유지,
IPv4 VXLAN Always, BGP 비활성화, workload/tunnel MTU `1400`으로 설치합니다.
노드 간 UDP 4789를 허용하고, Pod CIDR을 kubeadm과 Calico IPPool에서 일치시킵니다.
`inventory/group_vars/kubernetes/vars.yml`의 `kubernetes_calico_*`를 Installation에 반영합니다.
Kubernetes 1.36용 공식 `v3_projectcalico_org.yaml`을 server-side apply한 뒤 Tigera Operator를 설치합니다.
Operator의 hostNetwork와 taint toleration으로 초기 NotReady 상태에서도 시작할 수 있습니다.
Operator가 Installation API를 등록하면 `linuxDataplane: Iptables`, `bgp: Disabled`,
`ipPools[].encapsulation: VXLAN`, `mtu: 1400`과 NodeInternalIP 자동 감지를 명시합니다.
API server·Goldmane·Whisker 등 선택 구성은 설치하지 않습니다.
MTU 1400은 경로 MTU 1450·IPv4 VXLAN·추가 암호화 없음이라는 전제이며 실제 Pod 통신으로 확인합니다.
Pod·Service CIDR 값은 Vault에 저장하며, Service CIDR 크기는 `/16`으로 선택했습니다.
연결할 다른 네트워크와 CIDR 충돌이 없음을 사용자 확인했습니다.

근거: [Calico 요구사항](https://docs.tigera.io/calico/3.33/getting-started/kubernetes/requirements),
[containerd 호환표와 LTS](https://containerd.io/releases/),
[Kubernetes 릴리스](https://kubernetes.io/releases/),
[Calico MTU](https://docs.tigera.io/calico/latest/networking/configuring/mtu).

API LB 배치는 다음 중 하나로 선택합니다.

현재 선택은 CP 공동 설치이며, `kubernetes_manage_api_lb: true`로 설정했습니다.
API VIP의 VRRP router ID는 `51`이며 CP 3대가 같은 값을 사용합니다.
별도 LB VM은 만들지 않으며 VIP 예약·허용 주소·보안그룹·FIP 연결은 OpenStack에서 준비합니다.

- 별도 LB: `kubernetes_manage_api_lb: false`를 유지하고, LB 준비와 endpoint 도달성을 확인한 후
  `kubernetes_api_endpoint_ready: true`로 설정
- CP에 함께 설치: `kubernetes_manage_api_lb: true`로 설정하고 VIP·prefix·VRRP router ID를 지정.
  HAProxy는 기본 16443 포트에서 각 CP의 6443으로 전달하고, Keepalived는 CP 간 unicast로 VIP를 전환

공동 설치는 CP가 같은 사설 서브넷에 있다는 전제입니다. VIP 예약, Neutron 포트의 허용 주소,
FIP 연결, TCP 포트와 VRRP(IP protocol 112) 허용은 별도 OpenStack 작업입니다.
role은 보안그룹을 바꾸거나 방화벽을 해제하지 않습니다.

CIDR은 `192.0.2.0/24`처럼 IP 주소 범위를 나타냅니다. 노드·Pod·Service 주소 대역은
서로 겹치지 않게 정하고, 연결할 사내망·VPN 대역과의 충돌도 확인합니다.
NIC MTU는 네트워크 인터페이스가 전달할 수 있는 IP 패킷의 최대 바이트 크기입니다.
CNI 캡슐화에는 추가 공간이 필요할 수 있으므로 기존 Docker MTU를 그대로 적용하지 않습니다.
role은 VM NIC MTU를 변경하지 않고 입력값과 실제 값이 같은지 검사합니다.
CNI MTU 설정을 설치에 반영하며, 사내망·VPN 대역 충돌은 실행 전에 확인합니다.

### 설치와 재실행

CCM 자격 증명은 기존 Vault 네 변수와 분리하여 Jenkins의 현재 셸 환경변수로 전달합니다.
아래는 Bash 기준이며, ID·Secret을 명령어에 직접 쓰지 않습니다. Secret 입력은 화면에 표시되지 않습니다.

```bash
read -r -p 'Application Credential ID: ' OS_APPLICATION_CREDENTIAL_ID
read -r -s -p 'Application Credential Secret: ' OS_APPLICATION_CREDENTIAL_SECRET
printf '\n'
export OS_APPLICATION_CREDENTIAL_ID OS_APPLICATION_CREDENTIAL_SECRET

# VM 등록·변수 입력·SSH/sudo·OpenStack 네트워크 준비 후 전체 클러스터 실행
ansible-playbook playbooks/kubernetes/site.yml --ask-vault-pass

# 실행이 끝나면 셸에서도 지웁니다. 재실행 시 다시 입력합니다.
unset OS_APPLICATION_CREDENTIAL_ID OS_APPLICATION_CREDENTIAL_SECRET

# VM에 접속하지 않는 로컬 검증. Python 3.11 이상과 Ansible 필요
python3 roles/kubernetes/tests/verify.py
```

로컬 RPC 소켓 실행이 제한된 환경에서는 Ansible Python 환경에서
`python3 roles/kubernetes/tests/verify_addons.py --offline`으로 API 모의 응답·실제 템플릿·사전 조건을 검사할 수 있습니다.
이 검사는 실제 Ansible task 실행과 실패 시 Namespace 정리 통합 검증을 대신하지 않습니다.

`preflight`는 VM 설정을 바꾸기 전에 자격 증명 유무·프로젝트·리전·VM 이름의 유일성,
Nova VM/Flavor 조회와 Neutron 포트 조회 및 inventory의 사설 IP 일치를 CP 각각에서 검사합니다.
기존 TCP 연결 확인·VM 목록 조회만으로는 Neutron 권한까지 검증한 것이 아닙니다.
API 정책에 따라 `reader`의 조회가 거절되면 정책·프로젝트 권한을 먼저 점검하고 admin 권한을 무조건 부여하지 않습니다.
실제 ID·Secret과 인증 응답은 `no_log`로 숨기고 stdin으로 전달합니다.
해당 SSH 작업은 pipelining을 사용하며, 별도 `cloud.conf` 임시 파일을 만들지 않습니다.
CCM 설정은 `kube-system`의 `dangubi-openstack-cloud-config` Secret에 저장되며,
Secret 변경 시 Pod template의 해시가 바뀌어 CCM을 다시 시작합니다.
Kubernetes Secret의 base64는 암호화가 아니므로 해당 Secret에 대한 RBAC 접근을 제한해야 합니다.
Jenkins 자동 작업에서는 Credentials Binding으로 같은 두 환경변수를 주입할 수 있습니다.

실행 중 swap을 비활성화하고 fstab의 swap 항목을 주석 처리하며, 커널 모듈·sysctl·APT 저장소를 구성합니다.
선택한 containerd/Kubernetes 패키지는 설치 후 hold합니다. 최초 init/join 성공 노드에 관리 마커를 남겨
재실행 시 init/join을 생략합니다. 이미 가입한 노드의 패키지 버전 변경과 endpoint 변경은 중단합니다.
이 플레이북은 초기 구축용이며 `--limit`, `--check`, 노드 증설·업그레이드는 지원하지 않습니다.

기존 또는 init/join 도중 실패한 노드는 자동 reset하지 않습니다. 오류 원인을 점검한 뒤 수동 복구해야 합니다.
디스크 포맷·마운트, local PV 생성, kubeconfig의 Jenkins 배포는 수행하지 않습니다.
관리용 kubeconfig는 첫 CP의 `/etc/kubernetes/admin.conf`에 있으며 cluster-admin 권한이므로
별도 권한 관리 없이 Jenkins 작업이나 일반 사용자에게 배포하지 않습니다.
join token은 단기 발급 후 회수하고, 임시 join 설정은 성공·실패 시 삭제합니다.

### 교체한 Worker 한 대 재가입

새 VM의 SSH 주소·사설 IP·물리 호스트·NIC가 inventory와 일치하는지 확인합니다.
이름을 재사용할 때 기존 VM이 종료됐고 워크로드 정리가 끝났다면, Control Plane에서
`kubectl --kubeconfig /etc/kubernetes/admin.conf delete node <기존-worker-이름>`으로 남아 있는 기존 Node를 제거합니다.
로컬 PV를 사용 중이면 재가입 전에 새 VM의 데이터 디스크와 마운트를 확인합니다.

Jenkins VM의 `ansible` 디렉터리에서 대상 Worker 한 대를 지정합니다.

```bash
ansible-playbook -i inventory/hosts.yml playbooks/kubernetes/rejoin-worker.yml \
  --limit k8s-worker-4 --ask-vault-pass
```

첫 Control Plane의 API를 확인한 뒤 Worker를 준비하고 기존 클러스터에 가입시켜 `Ready`까지 기다립니다.
OpenStack CCM을 사용하는 경우 재가입한 Node의 `spec.providerID`가 새 VM의 UUID와 일치하는지도 확인합니다.

### 초기 구축 검증

최종 검증은 API 응답, 7개 노드 Ready, inventory와 같은 InternalIP, 실제 OpenStack VM UUID와 같은
providerID, CCM 미초기화 taint 해제, Calico·kube-proxy·CoreDNS rollout입니다.
이어서 임시 Namespace와 Worker별 HTTP Pod 1개 및 ClusterIP Service를 생성합니다.
모든 Worker에서 Kubernetes/테스트 Service DNS 조회, Service HTTP 접근과 4개 Worker의 Pod IP 접근을 검사합니다.
테스트 Namespace는 성공·실패 모두 정리하며, 이미지 다운로드·초기 조정 대기는 기본 600초입니다.
CP의 GitHub 원본 매니페스트 다운로드와 노드의 registry.k8s.io·quay.io·Docker Hub 이미지 다운로드가 가능해야 합니다.
프로세스 강제 종료나 API 불통으로 정리에 실패하면 `dangubi-network-check-`로 시작하는 Namespace를 확인합니다.
Calico/CCM 설치 도중에는 NotReady·미초기화 taint가 나타날 수 있지만, 이를 남긴 채 구축 성공으로 보고하지 않습니다.

### 클러스터 초기 구성과 서비스 배포

Ansible은 VM의 OS·containerd·kubeadm/kubelet과 클러스터 init/join, Calico·CCM과 네트워크 검증을 구성합니다.
클러스터 위의 애플리케이션 매니페스트는 별도 레포에서 관리합니다.

이 플레이북의 최종 검증이 끝난 뒤 `playbooks/kubernetes/argocd.yml`로 Argo CD를 최초 설치하고,
별도 레포의 Application을 등록해 서비스들을 동기화합니다. Application 등록은 현재 role에 포함되지 않습니다.
Cinder CSI·MetalLB 등의 후속 플랫폼 구성도 의존 순서에 맞춰 Argo CD로 관리할 수 있습니다.
Calico·CCM은 현재 Ansible이 관리하므로 같은 리소스를 Argo CD에서 동시에 관리하지 않습니다.

Argo CD는 일반 YAML뿐 아니라 Helm chart와 Kustomize 구성을 사용할 수 있습니다.
대안으로 직접 `kubectl apply`, Helm CLI, Jenkins 파이프라인을 통한 배포도 가능합니다.
같은 리소스를 Argo CD와 별도 배포 작업이 동시에 관리하지 않도록 담당을 구분합니다.
서비스 최초 배포와 별도로 DB 복제 그룹 초기화·백업·복구 설정도 필요합니다.

### Argo CD 설치

`roles/kubernetes/argocd`가 버전을 고정한 공식 `install.yaml`(비 HA)을 `argocd` Namespace에 server-side apply하고,
Workload 7개의 rollout을 확인합니다. 버전은 `inventory/group_vars/kubernetes/vars.yml`의 `kubernetes_argocd_version`에 있습니다.
공식 매니페스트의 ClusterRoleBinding이 `argocd` Namespace를 고정 참조하므로 Namespace 이름은 바꾸지 않습니다.

```bash
ansible-playbook playbooks/kubernetes/argocd.yml --syntax-check --ask-vault-pass
ansible-playbook playbooks/kubernetes/argocd.yml --ask-vault-pass
```

- 실행 대상: 첫 CP(`k8s-control-1`). CCM 자격 증명 환경변수는 필요 없습니다.
- 재실행해도 매니페스트 차이가 없으면 적용을 생략합니다.
- CP의 GitHub 원본 다운로드와 노드의 `quay.io`·`ghcr.io`·`public.ecr.aws` 이미지 다운로드가 가능해야 합니다.
- Service는 ClusterIP입니다. MetalLB·Ingress 구성 전까지는 포트 포워딩으로 접속합니다.

```bash
# k8s-control-1에서: 초기 admin 비밀번호 확인과 포트 포워딩
sudo kubectl --kubeconfig /etc/kubernetes/admin.conf -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
sudo kubectl --kubeconfig /etc/kubernetes/admin.conf -n argocd port-forward svc/argocd-server 8443:443

# 접속할 PC에서 터널을 연 뒤 https://localhost:8443 접속 (자체 서명 인증서)
ssh -L 8443:127.0.0.1:8443 ubuntu@10.20.0.111
```

로그인 후 admin 비밀번호를 변경하고 `argocd-initial-admin-secret`을 삭제합니다.

참고: [Argo CD 시작하기](https://argo-cd.readthedocs.io/en/stable/getting_started/),
[테스트된 Kubernetes 버전](https://argo-cd.readthedocs.io/en/stable/operator-manual/tested-kubernetes-versions/).

### OpenStack CCM과 Query Service

CCM(Cloud Controller Manager)은 Kubernetes와 클라우드 API를 연결하는 구성 요소입니다.
OpenStack CCM은 노드의 클라우드 정보 연동 등을 담당하며, Service 컨트롤러를 사용하면
`type: LoadBalancer` Service에 대응하는 OpenStack Octavia 로드밸런서도 관리합니다.
Cinder 볼륨의 생성·연결은 별도 구성 요소인 Cinder CSI 드라이버의 역할입니다.

현재 설계에서 LoadBalancer Service는 Query API용 `query-svc`이며, MetalLB가 VIP 할당과
L2 광고를 담당합니다. Kubernetes API 앞의 HAProxy·Keepalived는 별도 진입점입니다.
CCM은 `cloud-node`와 `cloud-node-lifecycle` 컨트롤러만 사용합니다.
Service 컨트롤러는 MetalLB와의 중복 관리를 피하기 위해, Route 컨트롤러는 Calico VXLAN을 사용하므로 비활성화합니다.
Keystone 인증 주소는 `http://10.10.0.10:5000`, 리전은 `RegionOne`입니다.
`ubi` 프로젝트의 `reader` 애플리케이션 자격 증명으로 인증과 Kubernetes VM 7대 조회를 확인했습니다.
자격 증명 ID·Secret의 실제 값은 Git에 포함하지 않으며, Ansible 실행 시 환경변수로 주입합니다.
MetalLB의 L2 광고와 FIP 연결은 실제 Neutron 환경에서 동작을 검증해야 합니다.

참고: [Kubernetes CCM](https://kubernetes.io/docs/concepts/architecture/cloud-controller/),
[OpenStack CCM](https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/openstack-cloud-controller-manager/using-openstack-cloud-controller-manager.md),
[Argo CD 구성](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/).
