locals {
  # 장치에 연결하지 않고 Neutron에서 VIP 주소를 예약하는 포트입니다.
  vip_ports = {
    "k8s-api-vip" = {
      fixed_ip    = "172.16.10.10"
      mac_address = "fa:16:3e:8c:37:c8"
    }
    "query-vip" = {
      fixed_ip    = "172.16.10.200"
      mac_address = "fa:16:3e:f5:c2:71"
    }
    "argo-vip" = {
      fixed_ip    = "172.16.10.201"
      mac_address = "fa:16:3e:a8:33:a6"
    }
  }
  vip_port_security_group_ids = toset([data.openstack_networking_secgroup_v2.vip_default.id])
}

data "openstack_networking_secgroup_v2" "vip_default" {
  name      = "default"
  tenant_id = var.project_ids.ubi
}

resource "openstack_networking_port_v2" "vip_ports" {
  for_each = local.vip_ports

  name                  = each.key
  network_id            = openstack_networking_network_v2.networks["k8s-net"].id
  tenant_id             = var.project_ids.ubi
  admin_state_up        = true
  mac_address           = each.value.mac_address
  port_security_enabled = true
  security_group_ids    = local.vip_port_security_group_ids

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.subnets["k8s-subnet"].id
    ip_address = each.value.fixed_ip
  }

  lifecycle {
    # Provider 3.4는 인수 시 실제 IP와 보안 그룹을 all_* 속성에 기록합니다.
    # 기존 포트에 값을 다시 쓰지 않고 아래 조건으로 일치를 확인합니다.
    ignore_changes = [fixed_ip, security_group_ids]

    postcondition {
      condition     = toset(self.all_fixed_ips) == toset([each.value.fixed_ip])
      error_message = "${each.key} 예약 포트의 실제 고정 IP가 코드의 설정과 다릅니다."
    }

    postcondition {
      condition     = self.all_security_group_ids == local.vip_port_security_group_ids
      error_message = "${each.key} 예약 포트에 ubi 프로젝트의 default 보안 그룹만 연결되어 있어야 합니다."
    }
  }
}
