# 물리망과 연결되는 ext-net은 flat, 내부 네트워크는 VXLAN을 사용합니다.
# 내부망 MTU 1450은 현재 터널 환경의 값이며 segmentation_id는 기존 VXLAN 식별자입니다.
locals {
  networks = {
    "ext-net" = {
      external         = true
      mtu              = 1500
      project_id       = var.project_ids.external
      network_type     = "flat"
      physical_network = "physnet1"
      segmentation_id  = 0
    }
    "k8s-net" = {
      external         = false
      mtu              = 1450
      project_id       = var.project_ids.ubi
      network_type     = "vxlan"
      physical_network = null
      segmentation_id  = 829
    }
    "ops-net" = {
      external         = false
      mtu              = 1450
      project_id       = var.project_ids.ubi
      network_type     = "vxlan"
      physical_network = null
      segmentation_id  = 902
    }
  }
}

resource "openstack_networking_network_v2" "networks" {
  for_each = local.networks

  name                  = each.key
  tenant_id             = each.value.project_id
  admin_state_up        = true
  external              = each.value.external
  mtu                   = each.value.mtu
  port_security_enabled = true
  shared                = false

  segments {
    # physnet1은 OpenStack 호스트에 이미 구성된 물리망 매핑을 참조합니다.
    # 세그먼트 변경 지원 여부는 Neutron 설정에 따라 달라 plan 확인이 필요합니다.
    network_type     = each.value.network_type
    physical_network = each.value.physical_network
    segmentation_id  = each.value.segmentation_id
  }
}
