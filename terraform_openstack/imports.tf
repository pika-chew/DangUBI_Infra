# 이 파일도 항상 읽히지만, import_existing=false이면 아래 조회와 import 대상은 모두 비어 있습니다.
# 기존 state의 resource 주소와 for_each 키를 유지하므로 다시 import할 필요는 없습니다.
locals {
  import_networks = {
    "ext-net" = "external"
    "k8s-net" = "ubi"
    "ops-net" = "ubi"
  }
  import_subnets = {
    "ext-subnet" = "ext-net"
    "k8s-subnet" = "k8s-net"
    "ops-subnet" = "ops-net"
  }
  import_router_interfaces = {
    "k8s-subnet" = "172.16.10.1"
    "ops-subnet" = "172.16.20.1"
  }
  # 포트 이름과 VM 이름은 다릅니다. 포트의 device_id가 연결된 Nova VM의 UUID입니다.
  import_ports = {
    "observability-port" = { network = "ops-net", vm_name = "observability-vm" }
    "jenkins-port"       = { network = "ops-net", vm_name = "jenkins-vm" }
    "vault"              = { network = "ops-net", vm_name = "vault" }
    "k8s-cp1-port"       = { network = "k8s-net", vm_name = "k8s-control-1" }
    "k8s-cp2-port"       = { network = "k8s-net", vm_name = "k8s-control-2" }
    "k8s-cp3-port"       = { network = "k8s-net", vm_name = "k8s-control-3" }
    "k8s-worker1-port"   = { network = "k8s-net", vm_name = "k8s-worker-1" }
    "k8s-worker2-port"   = { network = "k8s-net", vm_name = "k8s-worker-2" }
    "k8s-worker3-port"   = { network = "k8s-net", vm_name = "k8s-worker-3" }
    "k8s-worker4-port"   = { network = "k8s-net", vm_name = "k8s-worker-4" }
  }
}

# 다른 프로젝트의 동명 리소스를 선택하지 않도록 소유자와 네트워크로도 범위를 좁힙니다.
# 생성 예정인 리소스의 UUID에 의존하지 않도록 모듈의 resource 대신 별도 data로 조회합니다.
data "openstack_networking_network_v2" "existing" {
  for_each = var.import_existing ? local.import_networks : {}

  name      = each.key
  tenant_id = data.openstack_identity_project_v3.projects[each.value].id
}

data "openstack_networking_subnet_v2" "existing" {
  for_each = var.import_existing ? local.import_subnets : {}

  name       = each.key
  network_id = data.openstack_networking_network_v2.existing[each.value].id
  tenant_id  = data.openstack_identity_project_v3.projects[local.import_networks[each.value]].id
}

data "openstack_networking_router_v2" "existing" {
  for_each = var.import_existing ? toset(["main-router"]) : toset([])

  name      = each.key
  tenant_id = data.openstack_identity_project_v3.projects["ubi"].id
}

# 인터페이스는 포트 UUID로 인수합니다. 라우터, 내부망, 게이트웨이 IP로 조회 대상을 좁힙니다.
data "openstack_networking_port_v2" "router_interfaces" {
  for_each = var.import_existing ? local.import_router_interfaces : {}

  device_id  = data.openstack_networking_router_v2.existing["main-router"].id
  network_id = data.openstack_networking_network_v2.existing[local.import_subnets[each.key]].id
  fixed_ip   = each.value
}

data "openstack_networking_port_v2" "existing" {
  for_each = var.import_existing ? local.import_ports : {}

  name       = each.key
  project_id = data.openstack_identity_project_v3.projects["ubi"].id
  network_id = data.openstack_networking_network_v2.existing[each.value.network].id

  lifecycle {
    # 연결이 끊겼거나 VM 이외의 장치에 연결된 포트를 잘못 인수하는 것을 방지합니다.
    postcondition {
      condition     = try(startswith(self.device_owner, "compute:"), false) && try(length(self.device_id) > 0, false)
      error_message = "${each.key} 포트가 Nova VM에 연결되어 있지 않습니다. 연결 대상을 먼저 확인하세요."
    }
  }
}

# 예약 포트는 VM에 연결되지 않으므로 Nova VM 조회 대상에 포함하지 않습니다.
data "openstack_networking_port_v2" "vip_ports" {
  for_each = var.import_existing ? toset(["k8s-api-vip", "query-vip", "argo-vip"]) : toset([])

  name       = each.key
  project_id = data.openstack_identity_project_v3.projects["ubi"].id
  network_id = data.openstack_networking_network_v2.existing["k8s-net"].id

  lifecycle {
    postcondition {
      condition     = self.device_id == null || self.device_id == ""
      error_message = "${each.key} 예약 포트에 장치가 연결되어 있습니다. 연결 대상을 먼저 확인하세요."
    }
  }
}

data "openstack_networking_floatingip_v2" "existing" {
  for_each = var.import_existing ? module.network.floating_ip_addresses : toset([])

  address   = each.key
  tenant_id = data.openstack_identity_project_v3.projects["ubi"].id
  # 조회에는 외부 네트워크 UUID를, 리소스의 pool에는 네트워크 이름을 사용합니다.
  pool = data.openstack_networking_network_v2.existing["ext-net"].id
}

data "openstack_networking_secgroup_v2" "existing" {
  for_each = var.import_existing ? module.network.security_group_names : toset([])

  name      = each.key
  tenant_id = data.openstack_identity_project_v3.projects["ubi"].id
}

# Provider 3.4의 VM 단일 조회는 이름 검색을 지원하지 않아 포트에서 얻은 UUID를 사용합니다.
data "openstack_compute_instance_v2" "existing" {
  for_each = var.import_existing ? local.import_ports : {}

  id = data.openstack_networking_port_v2.existing[each.key].device_id

  lifecycle {
    postcondition {
      condition     = self.name == each.value.vm_name
      error_message = "${each.key} 포트의 연결 VM이 예상한 ${each.value.vm_name}과 다릅니다."
    }
  }
}

import {
  for_each = data.openstack_networking_network_v2.existing
  to       = module.network.openstack_networking_network_v2.networks[each.key]
  id       = each.value.id
}

import {
  for_each = data.openstack_networking_subnet_v2.existing
  to       = module.network.openstack_networking_subnet_v2.subnets[each.key]
  id       = each.value.id
}

import {
  for_each = data.openstack_networking_router_v2.existing
  to       = module.network.openstack_networking_router_v2.main
  id       = each.value.id
}

import {
  for_each = data.openstack_networking_port_v2.router_interfaces
  to       = module.network.openstack_networking_router_interface_v2.internal[each.key]
  id       = each.value.id
}

import {
  for_each = { for name, port in local.import_ports : name => port if var.import_existing && port.network == "ops-net" }
  to       = module.network.openstack_networking_port_v2.ops_ports[each.key]
  id       = data.openstack_networking_port_v2.existing[each.key].id
}

import {
  for_each = { for name, port in local.import_ports : name => port if var.import_existing && port.network == "k8s-net" }
  to       = module.network.openstack_networking_port_v2.k8s_ports[each.key]
  id       = data.openstack_networking_port_v2.existing[each.key].id
}

import {
  for_each = data.openstack_networking_port_v2.vip_ports
  to       = module.network.openstack_networking_port_v2.vip_ports[each.key]
  id       = each.value.id
}

import {
  for_each = data.openstack_networking_floatingip_v2.existing
  to       = module.network.openstack_networking_floatingip_v2.floating_ips[each.key]
  id       = each.value.id
}

import {
  for_each = data.openstack_networking_secgroup_v2.existing
  to       = module.network.openstack_networking_secgroup_v2.groups[each.key]
  id       = each.value.id
}

import {
  for_each = var.import_existing ? toset(["observability-port"]) : toset([])
  to       = module.compute.openstack_compute_instance_v2.observability_vm
  id       = data.openstack_compute_instance_v2.existing[each.key].id
}

import {
  for_each = var.import_existing ? toset(["jenkins-port"]) : toset([])
  to       = module.compute.openstack_compute_instance_v2.jenkins_vm
  id       = data.openstack_compute_instance_v2.existing[each.key].id
}

import {
  for_each = var.import_existing ? toset(["vault"]) : toset([])
  to       = module.compute.openstack_compute_instance_v2.vault
  id       = data.openstack_compute_instance_v2.existing[each.key].id
}

import {
  for_each = { for name, port in local.import_ports : name => port if var.import_existing && startswith(port.vm_name, "k8s-control-") }
  to       = module.compute.openstack_compute_instance_v2.k8s_control_plane[each.value.vm_name]
  id       = data.openstack_compute_instance_v2.existing[each.key].id
}

import {
  for_each = { for name, port in local.import_ports : name => port if var.import_existing && startswith(port.vm_name, "k8s-worker-") }
  to       = module.compute.openstack_compute_instance_v2.k8s_workers[each.value.vm_name]
  id       = data.openstack_compute_instance_v2.existing[each.key].id
}
