# project_ids는 소유권 설정에도 사용하고, 나머지 UUID 목록은 import 대상을 식별합니다.
variable "neutron" {
  description = "기존 Neutron 네트워크, 서브넷, 포트의 UUID 및 소유 프로젝트 ID입니다."
  type = object({
    project_ids = object({
      # external은 ext-net을 소유한 admin 프로젝트를 가리키는 코드 내부의 키입니다.
      external = string
      ubi      = string
    })
    network_ids = object({
      ext-net = string
      k8s-net = string
      ops-net = string
    })
    subnet_ids = object({
      ext-subnet = string
      k8s-subnet = string
      ops-subnet = string
    })
    ops_port_ids = object({
      observability-port = string
      jenkins-port       = string
      vault              = string
    })
    k8s_port_ids = object({
      k8s-cp1-port     = string
      k8s-cp2-port     = string
      k8s-cp3-port     = string
      k8s-worker1-port = string
      k8s-worker2-port = string
      k8s-worker3-port = string
      k8s-worker4-port = string
    })
  })
}

# Provider 인증은 루트에서 상속하며 compute 모듈과 같은 state에 기록합니다.
module "network" {
  source = "./modules/network"

  project_ids = var.neutron.project_ids
}

# UUID 목록의 키는 네트워크 모듈 locals의 이름과 일치해야 합니다.
# import 계획에 생성·수정·삭제가 있으면 실제 설정과 코드의 차이를 먼저 확인합니다.
import {
  for_each = var.neutron.network_ids
  to       = module.network.openstack_networking_network_v2.networks[each.key]
  id       = each.value
}

import {
  for_each = var.neutron.subnet_ids
  to       = module.network.openstack_networking_subnet_v2.subnets[each.key]
  id       = each.value
}

import {
  for_each = var.neutron.ops_port_ids
  to       = module.network.openstack_networking_port_v2.ops_ports[each.key]
  id       = each.value
}

import {
  for_each = var.neutron.k8s_port_ids
  to       = module.network.openstack_networking_port_v2.k8s_ports[each.key]
  id       = each.value
}
