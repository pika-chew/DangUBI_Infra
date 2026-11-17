terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

variable "ubuntu_image_id" {
  description = "인스턴스가 공통으로 사용하는 Ubuntu 24.04 Glance 이미지의 UUID입니다."
  type        = string
}

variable "observability_flavor_id" {
  description = "observability-vm이 사용하는 기존 Nova Flavor의 UUID입니다."
  type        = string
}

variable "vault_flavor_id" {
  description = "vault가 사용하는 기존 Nova Flavor의 UUID입니다."
  type        = string
}

variable "jenkins_flavor_id" {
  description = "jenkins-vm이 사용하는 기존 Nova Flavor의 UUID입니다."
  type        = string
}

variable "k8s_control_flavor_id" {
  description = "Kubernetes 컨트롤 플레인이 공통으로 사용하는 기존 Nova Flavor의 UUID입니다."
  type        = string
}

locals {
  k8s_control_plane = {
    "k8s-control-1" = { availability_zone = "az-os-ctl3", fixed_ip = "172.16.10.11" }
    "k8s-control-2" = { availability_zone = "az-os-ctl2", fixed_ip = "172.16.10.12" }
    "k8s-control-3" = { availability_zone = "az-os-ctl1", fixed_ip = "172.16.10.13" }
  }
}

resource "openstack_compute_instance_v2" "observability_vm" {
  name              = "observability-vm"
  image_id          = var.ubuntu_image_id
  flavor_id         = var.observability_flavor_id
  key_pair          = "pika1-key"
  availability_zone = "nova"
  security_groups   = ["sg-obs", "sg-ssh"]

  network {
    name        = "ops-net"
    fixed_ip_v4 = "172.16.20.20"
  }
}

resource "openstack_compute_instance_v2" "vault" {
  name              = "vault"
  image_id          = var.ubuntu_image_id
  flavor_id         = var.vault_flavor_id
  key_pair          = "pika1-key"
  availability_zone = "nova"
  security_groups   = ["sg-ssh", "sg-vault"]

  network {
    name        = "ops-net"
    fixed_ip_v4 = "172.16.20.30"
  }
}

resource "openstack_compute_instance_v2" "jenkins_vm" {
  name              = "jenkins-vm"
  image_id          = var.ubuntu_image_id
  flavor_id         = var.jenkins_flavor_id
  key_pair          = "pika1-key"
  availability_zone = "nova"
  security_groups   = ["sg-jenkins", "sg-ssh"]

  network {
    name        = "ops-net"
    fixed_ip_v4 = "172.16.20.10"
  }
}

resource "openstack_compute_instance_v2" "k8s_control_plane" {
  for_each = local.k8s_control_plane

  name              = each.key
  image_id          = var.ubuntu_image_id
  flavor_id         = var.k8s_control_flavor_id
  key_pair          = "pika1-key"
  availability_zone = each.value.availability_zone
  security_groups   = ["sg-k8s", "sg-ssh"]

  network {
    name        = "k8s-net"
    fixed_ip_v4 = each.value.fixed_ip
  }
}
