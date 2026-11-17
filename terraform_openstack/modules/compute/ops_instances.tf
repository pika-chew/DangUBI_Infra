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
