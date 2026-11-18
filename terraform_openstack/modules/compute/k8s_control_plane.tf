# 현재 VM별 AZ와 고정 IP입니다. 맵의 키는 state 주소에 쓰이므로 이름 변경 시 이동 처리가 필요합니다.
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
    # Neutron 포트 리소스와 별도로 현재 VM의 연결을 표현합니다.
    # port 참조로 전환할 때는 기존 VM 교체 여부를 먼저 확인합니다.
    name        = "k8s-net"
    fixed_ip_v4 = each.value.fixed_ip
  }
}
