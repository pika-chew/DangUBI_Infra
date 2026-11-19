# 운영 VM 3대의 현재 사양과 연결을 표현합니다. AZ nova 안의 실제 호스트는 스케줄러가 선택합니다.
# 기존 VM은 state에 포트 UUID가 비어 있을 수 있어 실제 연결을 MAC 주소로 검증합니다.
resource "openstack_compute_instance_v2" "observability_vm" {
  name              = "observability-vm"
  image_id          = var.ubuntu_image_id
  flavor_id         = var.observability_flavor_id
  key_pair          = "pika1-key"
  availability_zone = "nova"

  network {
    port = var.instance_ports["observability-port"].id
  }

  lifecycle {
    ignore_changes = [network[0].port]

    postcondition {
      condition     = try(self.network[0].mac == var.instance_ports["observability-port"].mac_address, false)
      error_message = "observability-vm의 네트워크 MAC 주소가 observability-port와 다릅니다."
    }
  }
}

resource "openstack_compute_instance_v2" "vault" {
  name              = "vault"
  image_id          = var.ubuntu_image_id
  flavor_id         = var.vault_flavor_id
  key_pair          = "pika1-key"
  availability_zone = "nova"

  network {
    port = var.instance_ports["vault"].id
  }

  lifecycle {
    ignore_changes = [network[0].port]

    postcondition {
      condition     = try(self.network[0].mac == var.instance_ports["vault"].mac_address, false)
      error_message = "vault VM의 네트워크 MAC 주소가 vault 포트와 다릅니다."
    }
  }
}

# Jenkins 데이터 볼륨의 생성·연결은 별도 관리 대상이며 이 VM 블록에는 포함하지 않습니다.
resource "openstack_compute_instance_v2" "jenkins_vm" {
  name              = "jenkins-vm"
  image_id          = var.ubuntu_image_id
  flavor_id         = var.jenkins_flavor_id
  key_pair          = "pika1-key"
  availability_zone = "nova"

  network {
    port = var.instance_ports["jenkins-port"].id
  }

  lifecycle {
    ignore_changes = [network[0].port]

    postcondition {
      condition     = try(self.network[0].mac == var.instance_ports["jenkins-port"].mac_address, false)
      error_message = "jenkins-vm의 네트워크 MAC 주소가 jenkins-port와 다릅니다."
    }
  }
}
