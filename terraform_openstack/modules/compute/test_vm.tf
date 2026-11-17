resource "openstack_compute_instance_v2" "provisioning_test" {
  name              = "terraform-test-vm"
  image_id          = var.ubuntu_image_id
  flavor_id         = var.test_vm_flavor_id
  key_pair          = "pika1-key"
  availability_zone = "nova"
  security_groups   = ["sg-ssh"]

  network {
    uuid = var.ops_network_id
  }
}
