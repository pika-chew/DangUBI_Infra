terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

variable "ops_image_id" {
  description = "Jenkins, Observability, Vault 인스턴스가 공통으로 사용하는 Glance 이미지의 UUID입니다."
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

resource "openstack_compute_instance_v2" "observability_vm" {
  name              = "observability-vm"
  image_id          = var.ops_image_id
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
  image_id          = var.ops_image_id
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
  image_id          = var.ops_image_id
  flavor_id         = var.jenkins_flavor_id
  key_pair          = "pika1-key"
  availability_zone = "nova"
  security_groups   = ["sg-jenkins", "sg-ssh"]

  network {
    name        = "ops-net"
    fixed_ip_v4 = "172.16.20.10"
  }
}
