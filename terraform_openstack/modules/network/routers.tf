resource "openstack_networking_router_v2" "main" {
  name                = "main-router"
  tenant_id           = var.project_ids.ubi
  admin_state_up      = true
  external_network_id = openstack_networking_network_v2.networks["ext-net"].id
  enable_snat         = true

  # 라우터가 ext-net에서 사용하는 외부 게이트웨이 IP를 유지합니다.
  external_fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.subnets["ext-subnet"].id
    ip_address = "10.20.0.100"
  }

  # 새로 생성할 때도 Neutron의 고가용성 라우터로 요청합니다.
  value_specs = { ha = "true" }

  lifecycle {
    # Provider 3.4는 인수 시 HA 값을 value_specs에 읽어 오지 않습니다.
    # 설정과 state의 차이로 기존 라우터를 교체하지 않도록 합니다.
    ignore_changes = [value_specs]
  }
}

resource "openstack_networking_router_interface_v2" "internal" {
  for_each = toset(["k8s-subnet", "ops-subnet"])

  router_id = openstack_networking_router_v2.main.id
  # 서브넷을 연결하면 Neutron이 해당 서브넷의 게이트웨이 IP를 사용합니다.
  subnet_id = openstack_networking_subnet_v2.subnets[each.key].id
}
