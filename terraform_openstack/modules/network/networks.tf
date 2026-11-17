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
    network_type     = each.value.network_type
    physical_network = each.value.physical_network
    segmentation_id  = each.value.segmentation_id
  }
}
