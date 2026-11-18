# 운영 VM 3대의 현재 사양과 연결을 표현합니다. AZ nova 안의 실제 호스트는 스케줄러가 선택합니다.
# 기존 VM의 network를 port 참조로 바꾸면 교체가 계획될 수 있어 plan을 확인해야 합니다.
resource "openstack_compute_instance_v2" "observability_vm" {
  name              = "observability-vm"
  image_id          = var.ubuntu_image_id
  flavor_id         = var.observability_flavor_id
  key_pair          = "pika1-key"
  availability_zone = "nova"
  security_groups   = ["sg-obs", "sg-ssh"]

  network {
    name        = "ops-net"
    fixed_ip_v4 = "172.16.20.20"
  }
}

resource "openstack_compute_instance_v2" "vault" {
  name              = "vault"
  image_id          = var.ubuntu_image_id
  flavor_id         = var.vault_flavor_id
  key_pair          = "pika1-key"
  availability_zone = "nova"
  security_groups   = ["sg-ssh", "sg-vault"]

  network {
    name        = "ops-net"
    fixed_ip_v4 = "172.16.20.30"
  }
}

# Jenkins 데이터 볼륨의 생성·연결은 별도 관리 대상이며 이 VM 블록에는 포함하지 않습니다.
resource "openstack_compute_instance_v2" "jenkins_vm" {
  name              = "jenkins-vm"
  image_id          = var.ubuntu_image_id
  flavor_id         = var.jenkins_flavor_id
  key_pair          = "pika1-key"
  availability_zone = "nova"
  security_groups   = ["sg-jenkins", "sg-ssh"]

  network {
    name        = "ops-net"
    fixed_ip_v4 = "172.16.20.10"
  }
}
