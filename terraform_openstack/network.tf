variable "neutron" {
  description = "기존 Neutron 네트워크, 서브넷, 포트의 UUID 및 소유 프로젝트 ID입니다."
  type = object({
    project_ids = object({
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

module "network" {
  source = "./modules/network"

  project_ids = var.neutron.project_ids
}

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
