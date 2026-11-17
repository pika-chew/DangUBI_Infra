locals {
  k8s_workers = {
    "k8s-worker-1" = {
      availability_zone = "az-os-ctl3"
      fixed_ip          = "172.16.10.21"
      flavor_id         = var.k8s_worker_flavor_id
    }
    "k8s-worker-2" = {
      availability_zone = "az-os-ctl2"
      fixed_ip          = "172.16.10.22"
      flavor_id         = var.k8s_worker_flavor_id
    }
    "k8s-worker-3" = {
      availability_zone = "az-os-ctl1"
      fixed_ip          = "172.16.10.23"
      flavor_id         = var.k8s_worker_flavor_id
    }
    "k8s-worker-4" = {
      availability_zone = "nova"
      fixed_ip          = "172.16.10.24"
      flavor_id         = var.k8s_worker_cmp_flavor_id
    }
  }
}

resource "openstack_compute_instance_v2" "k8s_workers" {
  for_each = local.k8s_workers

  name              = each.key
  image_id          = var.ubuntu_image_id
  flavor_id         = each.value.flavor_id
  key_pair          = "pika1-key"
  availability_zone = each.value.availability_zone
  security_groups   = ["sg-argocd", "sg-k8s", "sg-ssh"]

  network {
    name        = "k8s-net"
    fixed_ip_v4 = each.value.fixed_ip
  }
}
