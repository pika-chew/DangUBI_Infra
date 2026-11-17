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

module "compute" {
  source = "./modules/compute"

  observability_image_id  = var.observability.image_id
  observability_flavor_id = var.observability.flavor_id
}

import {
  to = module.compute.openstack_compute_instance_v2.observability_vm
  id = var.observability.instance_id
}
