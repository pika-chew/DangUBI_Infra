# 현재 VM별 AZ와 Neutron 포트 이름입니다. 맵의 키는 state 주소에 사용합니다.
locals {
  k8s_control_plane = {
    "k8s-control-1" = { availability_zone = "az-os-ctl3", port_name = "k8s-cp1-port" }
    "k8s-control-2" = { availability_zone = "az-os-ctl2", port_name = "k8s-cp2-port" }
    "k8s-control-3" = { availability_zone = "az-os-ctl1", port_name = "k8s-cp3-port" }
  }
}

resource "openstack_compute_instance_v2" "k8s_control_plane" {
  for_each = local.k8s_control_plane

  name              = each.key
  image_id          = var.ubuntu_image_id
  flavor_id         = var.k8s_control_flavor_id
  key_pair          = "pika1-key"
  availability_zone = each.value.availability_zone

  network {
    port = var.instance_ports[each.value.port_name].id
  }

  lifecycle {
    # 이름으로 인수한 VM은 state의 port 값이 비어 있어 UUID 차이로 교체될 수 있습니다.
    ignore_changes = [network[0].port]

    postcondition {
      condition     = try(self.network[0].mac == var.instance_ports[each.value.port_name].mac_address, false)
      error_message = "${each.key} VM의 네트워크 MAC 주소가 지정한 Neutron 포트와 다릅니다."
    }
  }
}
