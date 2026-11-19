# 워커 1~3은 공통 Flavor, 워커 4는 더 큰 k8s-worker-cmp Flavor를 사용합니다.
# 맵의 키는 state 주소에 쓰이므로 이름 변경 시 이동 처리가 필요합니다.
locals {
  k8s_workers = {
    "k8s-worker-1" = {
      availability_zone = "az-os-ctl3"
      port_name         = "k8s-worker1-port"
      flavor_id         = var.k8s_worker_flavor_id
    }
    "k8s-worker-2" = {
      availability_zone = "az-os-ctl2"
      port_name         = "k8s-worker2-port"
      flavor_id         = var.k8s_worker_flavor_id
    }
    "k8s-worker-3" = {
      availability_zone = "az-os-ctl1"
      port_name         = "k8s-worker3-port"
      flavor_id         = var.k8s_worker_flavor_id
    }
    "k8s-worker-4" = {
      availability_zone = "nova"
      port_name         = "k8s-worker4-port"
      flavor_id         = var.k8s_worker_cmp_flavor_id
    }
  }
}

resource "openstack_compute_instance_v2" "k8s_workers" {
  for_each = local.k8s_workers

  name              = each.key
  image_id          = var.ubuntu_image_id
  flavor_id         = each.value.flavor_id
  key_pair          = "pika1-key"
  availability_zone = each.value.availability_zone

  network {
    port = var.instance_ports[each.value.port_name].id
  }

  lifecycle {
    # 인수한 VM의 기존 포트 연결은 MAC으로 검증하고 UUID 차이로 교체하지 않습니다.
    ignore_changes = [network[0].port]

    postcondition {
      condition     = try(self.network[0].mac == var.instance_ports[each.value.port_name].mac_address, false)
      error_message = "${each.key} VM의 네트워크 MAC 주소가 지정한 Neutron 포트와 다릅니다."
    }
  }
}
