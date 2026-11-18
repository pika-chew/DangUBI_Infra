# 기존 Kubernetes 보안 그룹의 UUID를 조회합니다. 공통 sg-ssh는 ports.tf의 조회 결과를 재사용합니다.
data "openstack_networking_secgroup_v2" "k8s" {
  for_each = toset(["sg-k8s", "sg-argocd"])

  name      = each.key
  tenant_id = var.project_ids.ubi
}

locals {
  k8s_control_plane_port_groups = toset([
    data.openstack_networking_secgroup_v2.ops["sg-ssh"].id,
    data.openstack_networking_secgroup_v2.k8s["sg-k8s"].id,
  ])
  # 워커는 컨트롤 플레인과 공통인 그룹에 sg-argocd를 추가합니다.
  k8s_worker_port_groups = setunion(local.k8s_control_plane_port_groups, toset([
    data.openstack_networking_secgroup_v2.k8s["sg-argocd"].id,
  ]))

  # 컨트롤 플레인은 API VIP 한 주소, 워커는 VIP용 CIDR 전체를 추가 송신 주소로 허용합니다.
  # 고정 IP와 MAC은 기존 포트 값을 보존합니다. 맵의 키는 import 대상 이름과 일치해야 합니다.
  k8s_ports = {
    "k8s-cp1-port" = {
      fixed_ip           = "172.16.10.11"
      mac_address        = "fa:16:3e:f3:3d:dd"
      allowed_address    = "172.16.10.10"
      security_group_ids = local.k8s_control_plane_port_groups
    }
    "k8s-cp2-port" = {
      fixed_ip           = "172.16.10.12"
      mac_address        = "fa:16:3e:c1:d5:ba"
      allowed_address    = "172.16.10.10"
      security_group_ids = local.k8s_control_plane_port_groups
    }
    "k8s-cp3-port" = {
      fixed_ip           = "172.16.10.13"
      mac_address        = "fa:16:3e:01:ac:5e"
      allowed_address    = "172.16.10.10"
      security_group_ids = local.k8s_control_plane_port_groups
    }
    "k8s-worker1-port" = {
      fixed_ip           = "172.16.10.21"
      mac_address        = "fa:16:3e:c0:9b:1a"
      allowed_address    = "172.16.10.192/26"
      security_group_ids = local.k8s_worker_port_groups
    }
    "k8s-worker2-port" = {
      fixed_ip           = "172.16.10.22"
      mac_address        = "fa:16:3e:b3:e0:15"
      allowed_address    = "172.16.10.192/26"
      security_group_ids = local.k8s_worker_port_groups
    }
    "k8s-worker3-port" = {
      fixed_ip           = "172.16.10.23"
      mac_address        = "fa:16:3e:a3:af:30"
      allowed_address    = "172.16.10.192/26"
      security_group_ids = local.k8s_worker_port_groups
    }
    "k8s-worker4-port" = {
      fixed_ip           = "172.16.10.24"
      mac_address        = "fa:16:3e:dc:22:c2"
      allowed_address    = "172.16.10.192/26"
      security_group_ids = local.k8s_worker_port_groups
    }
  }
}

resource "openstack_networking_port_v2" "k8s_ports" {
  for_each = local.k8s_ports

  name               = each.key
  network_id         = openstack_networking_network_v2.networks["k8s-net"].id
  tenant_id          = var.project_ids.ubi
  admin_state_up     = true
  mac_address        = each.value.mac_address
  security_group_ids = each.value.security_group_ids

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.subnets["k8s-subnet"].id
    ip_address = each.value.fixed_ip
  }

  allowed_address_pairs {
    # 포트 자신의 MAC과 같은 주소 쌍은 Provider가 MAC 생략 형태로 읽어 옵니다.
    # mac_address를 생략하면 Neutron이 이 포트의 MAC을 사용합니다.
    ip_address = each.value.allowed_address
  }

  lifecycle {
    # Provider 3.4는 import 시 고정 IP와 보안 그룹을 all_* 조회 속성에 기록합니다.
    # 생성 시에는 위 설정을 적용하지만, 기존 포트의 IP·보안 그룹 변경은 자동 반영하지 않습니다.
    # 아래 조건으로 조회값을 검증하고, 허용된 주소 쌍은 일반 변경 대상으로 관리합니다.
    ignore_changes = [fixed_ip, security_group_ids]

    postcondition {
      condition     = toset(self.all_fixed_ips) == toset([each.value.fixed_ip])
      error_message = "${each.key} 포트의 실제 고정 IP가 코드의 설정과 다릅니다."
    }

    postcondition {
      condition     = self.all_security_group_ids == each.value.security_group_ids
      error_message = "${each.key} 포트의 실제 보안 그룹이 코드의 설정과 다릅니다."
    }
  }
}
