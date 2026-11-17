terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

variable "observability_image_id" {
  description = "observability-vm이 사용하는 기존 Glance 이미지의 UUID입니다."
  type        = string
}

variable "observability_flavor_id" {
  description = "observability-vm이 사용하는 기존 Nova Flavor의 UUID입니다."
  type        = string
}

resource "openstack_compute_instance_v2" "observability_vm" {
  name              = "observability-vm"
  image_id          = var.observability_image_id
  flavor_id         = var.observability_flavor_id
  key_pair          = "pika1-key"
  availability_zone = "nova"
  security_groups   = ["sg-obs", "sg-ssh"]

  network {
    name        = "ops-net"
    fixed_ip_v4 = "172.16.20.20"
  }
}
