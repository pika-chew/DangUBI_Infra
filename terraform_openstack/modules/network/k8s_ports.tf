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
  k8s_worker_port_groups = setunion(local.k8s_control_plane_port_groups, toset([
    data.openstack_networking_secgroup_v2.k8s["sg-argocd"].id,
  ]))

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
    # The provider represents a pair using the port's own MAC without a MAC override.
    ip_address = each.value.allowed_address
  }

  lifecycle {
    # Provider 3.4 records these values in all_fixed_ips and all_security_group_ids during import.
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
