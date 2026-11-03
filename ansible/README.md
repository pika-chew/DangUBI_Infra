# DangUBI Ansible

Ansible로 OpenStack VM 위에 올라가는 인프라를 구축/관리합니다.

- Ansible Control Node: jenkins-1

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
# Docker 그룹 권한 적용을 위해 jenkins-1 VM에 다시 로그인
ansible-playbook playbooks/jenkins.yml
```
`jenkins-docker.yml`: Docker 공식 APT 저장소로 Docker Engine, Compose 플러그인 설치
`jenkins.yml`: `/opt/jenkins`에서 커스텀 이미지를 빌드하고 Docker Compose로 Jenkins 실행

- 접속: `http://<jenkins-1 주소>:8080`
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
