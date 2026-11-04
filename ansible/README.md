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

### Alloy (모니터링 VM 자기 감시)

```bash
ansible-playbook playbooks/alloy.yml --ask-vault-pass
```
`alloy.yml`: Grafana 공식 APT 저장소로 Alloy를 설치하고 systemd 서비스로 실행

- 수집: 호스트 메트릭(`prometheus.exporter.unix`), Alloy 자신의 상태(`prometheus.exporter.self`)
- 전송: `alloy_remote_write_url`로 remote write, 모든 메트릭에 `env`·`cluster` 라벨 추가
- 그룹별 설정(`alloy_cluster`, `alloy_remote_write_url`): `inventory/group_vars/<그룹>/vars.yml`
- 설정 파일: `/etc/alloy/config.alloy` (배포 전 `alloy fmt`로 문법 검사)
- 디버깅 UI: `127.0.0.1:12345` (외부 미노출, `ssh -L 12345:localhost:12345`로 접속)
