terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.4.0"
    }
  }
}

provider "openstack" {}

variable "observability" {
  description = "기존 observability-vm과 연결된 이미지 및 Flavor의 UUID입니다."
  type = object({
    instance_id = string
    image_id    = string
    flavor_id   = string
  })
}

variable "vault" {
  description = "기존 vault 인스턴스와 Flavor의 UUID입니다."
  type = object({
    instance_id = string
    flavor_id   = string
  })
}

variable "jenkins" {
  description = "기존 jenkins-vm 인스턴스와 Flavor의 UUID입니다."
  type = object({
    instance_id = string
    flavor_id   = string
  })
}

variable "k8s_control_plane" {
  description = "기존 Kubernetes 컨트롤 플레인 인스턴스와 공통 Flavor의 UUID입니다."
  type = object({
    flavor_id = string
    instance_ids = object({
      k8s-control-1 = string
      k8s-control-2 = string
      k8s-control-3 = string
    })
  })
}

variable "k8s_workers" {
  description = "기존 Kubernetes 워커 인스턴스와 두 종류의 Flavor UUID입니다."
  type = object({
    flavor_id     = string
    cmp_flavor_id = string
    instance_ids = object({
      k8s-worker-1 = string
      k8s-worker-2 = string
      k8s-worker-3 = string
      k8s-worker-4 = string
    })
  })
}

variable "test_vm_flavor_id" {
  description = "테스트 VM에 사용할 Flavor UUID입니다. 생략하면 기존 Jenkins VM과 같은 Flavor를 사용합니다."
  type        = string
  default     = null
}

module "compute" {
  source = "./modules/compute"

  ubuntu_image_id          = var.observability.image_id
  observability_flavor_id  = var.observability.flavor_id
  vault_flavor_id          = var.vault.flavor_id
  jenkins_flavor_id        = var.jenkins.flavor_id
  k8s_control_flavor_id    = var.k8s_control_plane.flavor_id
  k8s_worker_flavor_id     = var.k8s_workers.flavor_id
  k8s_worker_cmp_flavor_id = var.k8s_workers.cmp_flavor_id
  ops_network_id           = module.network.ops_network_id
  test_vm_flavor_id        = coalesce(var.test_vm_flavor_id, var.jenkins.flavor_id)
}

import {
  to = module.compute.openstack_compute_instance_v2.observability_vm
  id = var.observability.instance_id
}

import {
  to = module.compute.openstack_compute_instance_v2.vault
  id = var.vault.instance_id
}

import {
  to = module.compute.openstack_compute_instance_v2.jenkins_vm
  id = var.jenkins.instance_id
}

import {
  for_each = var.k8s_control_plane.instance_ids
  to       = module.compute.openstack_compute_instance_v2.k8s_control_plane[each.key]
  id       = each.value
}

import {
  for_each = var.k8s_workers.instance_ids
  to       = module.compute.openstack_compute_instance_v2.k8s_workers[each.key]
  id       = each.value
}
