# 실제 OpenStack API를 호출하지 않고 운영 모드에서 인수용 조회가 실행되지 않는지 검증합니다.
mock_provider "openstack" {
  mock_data "openstack_identity_project_v3" {
    defaults = { id = "mock-project" }
  }
  mock_data "openstack_images_image_v2" {
    defaults = { id = "mock-image" }
  }
  mock_data "openstack_compute_flavor_v2" {
    defaults = { id = "mock-flavor" }
  }
}

run "operation_skips_import_discovery" {
  command = plan

  assert {
    condition = (
      length(data.openstack_networking_network_v2.existing) == 0 &&
      length(data.openstack_networking_subnet_v2.existing) == 0 &&
      length(data.openstack_networking_router_v2.existing) == 0 &&
      length(data.openstack_networking_port_v2.router_interfaces) == 0 &&
      length(data.openstack_networking_port_v2.existing) == 0 &&
      length(data.openstack_networking_port_v2.vip_ports) == 0 &&
      length(data.openstack_networking_floatingip_v2.existing) == 0 &&
      length(data.openstack_compute_instance_v2.existing) == 0
    )
    error_message = "기본 운영 모드에서 import용 기존 리소스를 조회하면 안 됩니다."
  }
}
