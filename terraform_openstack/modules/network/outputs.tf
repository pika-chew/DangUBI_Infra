# Compute가 포트 UUID로 연결하고 실제 연결은 포트 MAC 주소로 확인합니다.
output "instance_ports" {
  value = {
    for name, port in merge(openstack_networking_port_v2.ops_ports, openstack_networking_port_v2.k8s_ports) : name => {
      id          = port.id
      mac_address = port.mac_address
    }
  }

  # 신규 VM이 부팅하기 전에 보안 그룹의 트래픽 규칙을 준비합니다.
  depends_on = [openstack_networking_secgroup_rule_v2.rules]
}
