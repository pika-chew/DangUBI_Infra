locals {
  # ext-net에서 할당된 Floating IP를 기존 Neutron 포트 이름에 매핑합니다.
  floating_ip_ports = {
    "10.20.0.110" = "k8s-api-vip"
    "10.20.0.111" = "k8s-cp1-port"
    "10.20.0.112" = "k8s-cp2-port"
    "10.20.0.113" = "k8s-cp3-port"
    "10.20.0.121" = "k8s-worker1-port"
    "10.20.0.122" = "k8s-worker2-port"
    "10.20.0.123" = "k8s-worker3-port"
    "10.20.0.124" = "k8s-worker4-port"
    "10.20.0.130" = "jenkins-port"
    "10.20.0.140" = "observability-port"
    "10.20.0.150" = "query-vip"
    "10.20.0.160" = "argo-vip"
    "10.20.0.170" = "vault"
  }

  floating_ip_target_ports = merge(
    openstack_networking_port_v2.k8s_ports,
    openstack_networking_port_v2.ops_ports,
    openstack_networking_port_v2.vip_ports,
  )
  floating_ip_target_settings = merge(local.k8s_ports, local.ops_ports, local.vip_ports)
}

resource "openstack_networking_floatingip_v2" "floating_ips" {
  for_each = local.floating_ip_ports

  pool      = openstack_networking_network_v2.networks["ext-net"].name
  tenant_id = var.project_ids.ubi
  address   = each.key
  port_id   = local.floating_ip_target_ports[each.value].id
  fixed_ip  = local.floating_ip_target_settings[each.value].fixed_ip

  # 새 환경에서 생성할 때 내부 서브넷과 외부망이 라우터를 통해 연결된 후 IP를 연결합니다.
  depends_on = [openstack_networking_router_interface_v2.internal]
}

# 루트의 import 조회가 할당 목록을 재사용할 수 있도록 주소를 넘깁니다.
output "floating_ip_addresses" {
  value = toset(keys(local.floating_ip_ports))
}
