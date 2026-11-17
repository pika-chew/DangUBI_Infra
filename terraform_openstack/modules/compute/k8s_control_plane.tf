locals {
  k8s_control_plane = {
    "k8s-control-1" = { availability_zone = "az-os-ctl3", fixed_ip = "172.16.10.11" }
    "k8s-control-2" = { availability_zone = "az-os-ctl2", fixed_ip = "172.16.10.12" }
    "k8s-control-3" = { availability_zone = "az-os-ctl1", fixed_ip = "172.16.10.13" }
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
