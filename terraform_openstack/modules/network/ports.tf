locals {
  ops_ports = {
    "observability-port" = {
      fixed_ip       = "172.16.20.20"
      mac_address    = "fa:16:3e:1c:88:a4"
      security_group = "sg-obs"
    }
    "jenkins-port" = {
      fixed_ip       = "172.16.20.10"
      mac_address    = "fa:16:3e:7b:71:03"
      security_group = "sg-jenkins"
    }
    vault = {
      fixed_ip       = "172.16.20.30"
      mac_address    = "fa:16:3e:a5:f5:d2"
      security_group = "sg-vault"
    }
  }

  ops_port_security_group_ids = {
    for name, port in local.ops_ports : name => toset([
      data.openstack_networking_secgroup_v2.ops["sg-ssh"].id,
      data.openstack_networking_secgroup_v2.ops[port.security_group].id,
    ])
  }
}

data "openstack_networking_secgroup_v2" "ops" {
  for_each = toset(concat(["sg-ssh"], [for port in values(local.ops_ports) : port.security_group]))

  name      = each.key
  tenant_id = var.project_ids.ubi
}

resource "openstack_networking_port_v2" "ops_ports" {
  for_each = local.ops_ports

  name               = each.key
  network_id         = openstack_networking_network_v2.networks["ops-net"].id
  tenant_id          = var.project_ids.ubi
  admin_state_up     = true
  mac_address        = each.value.mac_address
  security_group_ids = local.ops_port_security_group_ids[each.key]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.subnets["ops-subnet"].id
    ip_address = each.value.fixed_ip
  }

  lifecycle {
    # Provider 3.4 records these values in all_fixed_ips and all_security_group_ids during import.
    ignore_changes = [fixed_ip, security_group_ids]

    postcondition {
      condition     = toset(self.all_fixed_ips) == toset([each.value.fixed_ip])
      error_message = "${each.key} 포트의 실제 고정 IP가 코드의 설정과 다릅니다."
    }

    postcondition {
      condition     = self.all_security_group_ids == local.ops_port_security_group_ids[each.key]
      error_message = "${each.key} 포트의 실제 보안 그룹이 코드의 설정과 다릅니다."
    }
  }
}
