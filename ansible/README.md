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

- 주소: Floating IP `10.20.0.140` / 사설 IP `172.16.20.182`
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
# 최초 1회: Grafana 관리자 비밀번호를 Vault로 암호화해 저장
ansible-vault create inventory/group_vars/monitoring/vault.yml
#   vault_grafana_admin_password: <비밀번호>

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
- Grafana 데이터소스(Prometheus, Alertmanager): `roles/monitoring/files/grafana/provisioning/` 로 자동 등록
- Prometheus는 `--web.enable-remote-write-receiver`로 Alloy의 remote_write를 받음
- Alertmanager 수신자는 아직 `null`. Slack 웹훅이 준비되면 Vault에 넣고 `alertmanager.yml.j2`에 추가
- 설정 파일이 바뀌면 해당 컨테이너만 재시작(handler)
- Grafana 관리자 비밀번호는 Grafana DB가 처음 만들어질 때만 적용됨

---
<br>

## Kubernetes setup

OpenStack VM 위에 kubeadm + containerd로 단일 Kubernetes 클러스터를 구성합니다.
role은 OS·containerd 준비, 첫 Control Plane의 init, 나머지 Control Plane과 Worker의
순차 join을 수행합니다. VM이 아직 없으므로 실제 클러스터 구축은 검증 전입니다.
빈 설정값으로는 설치를 시작하지 않습니다.

- Control Plane VM 3대: ctl1·ctl2·ctl3에 각각 배치, stacked etcd 구성
- Worker VM 4대: ctl1·ctl2·ctl3·cmp1에 각각 배치
- ctl1·ctl2·ctl3·cmp1은 물리 호스트이며, Ansible 접속 대상은 그 위의 VM
- 실행 노드: 기존 jenkins-vm. Jenkins는 해당 VM의 Docker Compose 환경을 유지
- Roles: `roles/kubernetes/` 아래 기능별 role
- Playbook: `playbooks/kubernetes/site.yml`
- Inventory: 기존 `inventory/hosts.yml`의 `kubernetes` 그룹
- 공통 설정: `inventory/group_vars/kubernetes.yml`
- 대상 OS: Ubuntu 22.04/24.04, systemd, IPv4. 다른 OS와 IPv6는 현재 지원 범위에 포함하지 않음

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
├── verify/         # 7개 노드 등록 확인과 후속 작업 안내
└── tests/          # VM에 접속하지 않는 로컬 검증
```

실행 순서는 inventory 검증 → 전체 노드의 preflight/common/packages/containerd →
CP의 API LB → 첫 CP 초기화 → 추가 CP 순차 가입 → Worker 순차 가입 → 결과 확인입니다.
첫 CP는 inventory의 `kubernetes_control_plane` 그룹에서 첫 번째로 등록한 VM입니다.
추가 CP play는 `[1:]`로 첫 CP를 제외하며, `serial: 1`로 etcd 멤버를 한 대씩 추가합니다.
템플릿과 handler는 사용하는 role 안에 두고, 공통 입력값과 기본 설정은
`inventory/group_vars/kubernetes.yml` 한 곳에서 관리합니다.

### Inventory와 실행 전 확인

VM 생성 전이므로 Control Plane과 Worker 그룹은 비어 있고, 임시 VM 항목은 주석으로만 작성했습니다.
VM 생성 후 해당 그룹의 `hosts: {}`를 `hosts:`로 바꾸고 예시 항목을 활성화합니다.
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
ansible-playbook playbooks/kubernetes/site.yml --syntax-check

# VM을 inventory에 등록하고 SSH 접속을 준비한 후 실행
ansible kubernetes -m ping
```

`ping` 모듈은 ICMP ping이 아니라 SSH 접속과 대상 Python 실행을 확인합니다.
현재는 등록된 Kubernetes 호스트가 없으므로 실제 접속·설치 검증은 수행할 수 없습니다.

### 구축 전 확정할 항목

- VM의 OS·사양·사설 IP·네트워크 인터페이스, Kubernetes/containerd 버전
- CNI, Pod CIDR, Service CIDR, VM NIC MTU와 CNI의 MTU
- HAProxy·Keepalived 설치 위치, API VIP/FIP, 인증서, 보안그룹과 VIP 전환
- OpenStack CCM 사용 여부와 LoadBalancer Service 관리 범위
- Cinder·local PV용 디스크와 마운트 경로, OpenStack 접근 정보

`inventory/group_vars/kubernetes.yml`의 빈 값을 채운 뒤 실행합니다.
Kubernetes는 `kubernetes_version`과 APT의 정확한 `kubernetes_package_version`을 함께 지정하고,
containerd도 `kubernetes_containerd_package_version`에 저장소의 정확한 `containerd.io` 버전을 지정합니다.
role은 Docker Engine을 설치하지 않습니다. containerd 1.x/2.x에 맞춰 설정 스키마를 구분하며,
Kubernetes 패키지는 kubeadm v1beta4 설정을 지원하는 1.31 이상을 전제로 합니다.
이 하한은 해당 버전의 운영 지원 또는 최신 버전과의 호환성을 보장한다는 뜻은 아닙니다.
구축 시점에 지원되는 Kubernetes/containerd/CNI 조합을 선택해야 합니다.

API LB 배치는 다음 중 하나로 선택합니다.

- 별도 LB: `kubernetes_manage_api_lb: false`를 유지하고, LB 준비와 endpoint 도달성을 확인한 후
  `kubernetes_api_endpoint_ready: true`로 설정
- CP에 함께 설치: `kubernetes_manage_api_lb: true`로 설정하고 VIP·prefix·VRRP router ID를 지정.
  HAProxy는 기본 16443 포트에서 각 CP의 6443으로 전달하고, Keepalived는 CP 간 unicast로 VIP를 전환

공동 설치는 CP가 같은 사설 서브넷에 있다는 전제입니다. VIP 예약, Neutron 포트의 허용 주소,
FIP 연결, TCP 포트와 VRRP(IP protocol 112) 허용은 별도 OpenStack 작업입니다.
role은 보안그룹을 바꾸거나 방화벽을 해제하지 않습니다.

CIDR은 `172.16.10.0/24`처럼 IP 주소 범위를 나타냅니다. 노드·Pod·Service 주소 대역은
서로 겹치지 않게 정하고, 연결할 사내망·VPN 대역과의 충돌도 확인합니다.
NIC MTU는 네트워크 인터페이스가 전달할 수 있는 IP 패킷의 최대 바이트 크기입니다.
CNI 캡슐화에는 추가 공간이 필요할 수 있으므로 기존 Docker MTU를 그대로 적용하지 않습니다.
role은 VM NIC MTU를 변경하지 않고 입력값과 실제 값이 같은지 검사합니다.
CNI의 MTU 설정과 사내망·VPN 대역 충돌 확인은 별도로 수행합니다.

### 설치와 재실행

```bash
# VM 등록·변수 입력·SSH/sudo·OpenStack 네트워크 준비 후 전체 클러스터 실행
ansible-playbook playbooks/kubernetes/site.yml

# VM에 접속하지 않는 로컬 검증. Python 3.11 이상과 Ansible 필요
python3 roles/kubernetes/tests/verify.py
```

실행 중 swap을 비활성화하고 fstab의 swap 항목을 주석 처리하며, 커널 모듈·sysctl·APT 저장소를 구성합니다.
선택한 containerd/Kubernetes 패키지는 설치 후 hold합니다. 최초 init/join 성공 노드에 관리 마커를 남겨
재실행 시 init/join을 생략합니다. 이미 가입한 노드의 패키지 버전 변경과 endpoint 변경은 중단합니다.
이 플레이북은 초기 구축용이며 `--limit`, `--check`, 노드 증설·업그레이드는 지원하지 않습니다.

기존 또는 init/join 도중 실패한 노드는 자동 reset하지 않습니다. 오류 원인을 점검한 뒤 수동 복구해야 합니다.
디스크 포맷·마운트, local PV 생성, kubeconfig의 Jenkins 배포는 수행하지 않습니다.
관리용 kubeconfig는 첫 CP의 `/etc/kubernetes/admin.conf`에 있으며 cluster-admin 권한이므로
별도 권한 관리 없이 Jenkins 작업이나 일반 사용자에게 배포하지 않습니다.
join token은 단기 발급 후 회수하고, 임시 join 설정은 성공·실패 시 삭제합니다.

role의 마지막 검증은 API 응답과 7개 노드의 등록입니다. CNI 설치 전의 `NotReady`는 정상적인 중간 상태이며,
CCM 사용을 선택했다면 CCM 설치 전에는 미초기화 taint도 남을 수 있습니다.
CNI/CCM 구성 후 `kubectl get nodes`의 Ready 상태와 실제 Pod 통신·DNS를 별도로 검증해야 합니다.

### 클러스터 초기 구성과 서비스 배포

Ansible은 VM의 OS·containerd·kubeadm/kubelet과 클러스터 init/join을 구성합니다.
클러스터 위의 애플리케이션 매니페스트는 별도 레포에서 관리합니다.

Argo CD를 사용할 경우, 먼저 CNI 및 필요한 CCM 등 초기 구성을 적용해 Argo CD가 실행될 환경을
마련하고 Argo CD를 최초 설치합니다. 이후 별도 레포의 Application을 등록해 서비스들을 동기화합니다.
이 초기 설치 단계의 실행 주체와 레포 간 연결 방식은 아직 미확정이며, CNI/CCM/Argo CD 설치는 현재 role에 포함되지 않습니다.
후속 플랫폼 구성도 의존 순서에 맞춰 Argo CD로 관리할 수 있습니다.

Argo CD는 일반 YAML뿐 아니라 Helm chart와 Kustomize 구성을 사용할 수 있습니다.
대안으로 직접 `kubectl apply`, Helm CLI, Jenkins 파이프라인을 통한 배포도 가능합니다.
같은 리소스를 Argo CD와 별도 배포 작업이 동시에 관리하지 않도록 담당을 구분합니다.
서비스 최초 배포와 별도로 DB 복제 그룹 초기화·백업·복구 설정도 필요합니다.

### OpenStack CCM과 Query Service

CCM(Cloud Controller Manager)은 Kubernetes와 클라우드 API를 연결하는 구성 요소입니다.
OpenStack CCM은 노드의 클라우드 정보 연동 등을 담당하며, Service 컨트롤러를 사용하면
`type: LoadBalancer` Service에 대응하는 OpenStack Octavia 로드밸런서도 관리합니다.
Cinder 볼륨의 생성·연결은 별도 구성 요소인 Cinder CSI 드라이버의 역할입니다.

현재 설계에서 LoadBalancer Service는 Query API용 `query-svc`이며, MetalLB가 VIP 할당과
L2 광고를 담당하는 안입니다. Kubernetes API 앞의 HAProxy·Keepalived는 별도 진입점입니다.
CCM을 도입하더라도 동일한 `query-svc`를 CCM과 MetalLB가 중복 처리하지 않도록
설치 버전에 맞춰 Service 컨트롤러 비활성화 또는 지원되는 클래스 구분 등을 설정해야 합니다.
MetalLB의 L2 광고와 FIP 연결은 실제 Neutron 환경에서 동작을 검증해야 합니다.

참고: [Kubernetes CCM](https://kubernetes.io/docs/concepts/architecture/cloud-controller/),
[OpenStack CCM](https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/openstack-cloud-controller-manager/using-openstack-cloud-controller-manager.md),
[Argo CD 구성](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/).
