locals {
  # 키는 Horizon의 포트 이름입니다. VM 이름과 포트 이름은 다를 수 있습니다.
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

  # 각 포트에는 공통 SSH 그룹과 서비스별 그룹을 적용합니다.
  ops_port_security_group_ids = {
    for name, port in local.ops_ports : name => toset([
      data.openstack_networking_secgroup_v2.ops["sg-ssh"].id,
      data.openstack_networking_secgroup_v2.ops[port.security_group].id,
    ])
  }
}

# 기존 보안 그룹을 UBI 프로젝트 안에서 조회합니다. 그룹과 규칙 자체는 이 data로 관리하지 않습니다.
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
    # OpenStack Provider 3.4는 import 시 실제 고정 IP와 보안 그룹을
    # all_fixed_ips와 all_security_group_ids에 기록합니다.
    # 기존 포트에 값을 다시 쓰는 대신 아래 조건으로 코드와 일치하는지 확인합니다.
    # 생성 시에는 위 설정을 적용하지만, 기존 포트의 IP·보안 그룹 변경은 자동 반영하지 않습니다.
    ignore_changes = [fixed_ip, security_group_ids]

    # 조회값이 코드와 다르면 오류로 알려 import 또는 후속 작업에서 차이를 확인할 수 있게 합니다.
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
