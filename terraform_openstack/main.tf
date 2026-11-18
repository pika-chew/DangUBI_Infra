# 실행은 이 폴더에서 합니다. 같은 폴더의 main.tf와 network.tf를 함께 읽습니다.
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.4.0"
    }
  }
}

# 인증과 리전은 OpenRC의 OS_* 환경 변수 또는 OS_CLOUD 설정에서 읽습니다.
# backend를 지정하지 않아 현재 state는 이 폴더의 terraform.tfstate에 저장됩니다.
provider "openstack" {}

# 실제 UUID는 Git에서 제외된 import.tfvars로 전달합니다.
# instance_id는 import 대상 식별에, image_id와 flavor_id는 VM 설정에도 사용합니다.
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

module "compute" {
  source = "./modules/compute"

  # VM 10대가 동일한 Ubuntu 이미지를 쓰므로 observability의 이미지 ID를 공유합니다.
  ubuntu_image_id          = var.observability.image_id
  observability_flavor_id  = var.observability.flavor_id
  vault_flavor_id          = var.vault.flavor_id
  jenkins_flavor_id        = var.jenkins.flavor_id
  k8s_control_flavor_id    = var.k8s_control_plane.flavor_id
  k8s_worker_flavor_id     = var.k8s_workers.flavor_id
  k8s_worker_cmp_flavor_id = var.k8s_workers.cmp_flavor_id
}

# import는 기존 VM UUID와 모듈의 리소스 주소를 연결하며 apply할 때 state에 기록합니다.
# 이미 등록된 주소는 같은 state에서 다시 가져오지 않습니다.
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

# instance_ids의 키를 compute 모듈의 for_each 키와 맞춰 같은 VM을 추적합니다.
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
