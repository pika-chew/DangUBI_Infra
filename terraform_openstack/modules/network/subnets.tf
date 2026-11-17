locals {
  subnets = {
    "ext-subnet" = {
      network_name    = "ext-net"
      cidr            = "10.20.0.0/24"
      gateway_ip      = "10.20.0.1"
      enable_dhcp     = false
      dns_nameservers = []
      pool_start      = "10.20.0.100"
      pool_end        = "10.20.0.250"
    }
    "k8s-subnet" = {
      network_name    = "k8s-net"
      cidr            = "172.16.10.0/24"
      gateway_ip      = "172.16.10.1"
      enable_dhcp     = true
      dns_nameservers = ["8.8.8.8"]
      pool_start      = "172.16.10.100"
      pool_end        = "172.16.10.191"
    }
    "ops-subnet" = {
      network_name    = "ops-net"
      cidr            = "172.16.20.0/24"
      gateway_ip      = "172.16.20.1"
      enable_dhcp     = true
      dns_nameservers = ["8.8.8.8"]
      pool_start      = "172.16.20.100"
      pool_end        = "172.16.20.191"
    }
  }
}

resource "openstack_networking_subnet_v2" "subnets" {
  for_each = local.subnets

  name            = each.key
  network_id      = openstack_networking_network_v2.networks[each.value.network_name].id
  tenant_id       = local.networks[each.value.network_name].project_id
  cidr            = each.value.cidr
  ip_version      = 4
  gateway_ip      = each.value.gateway_ip
  enable_dhcp     = each.value.enable_dhcp
  dns_nameservers = each.value.dns_nameservers

  allocation_pool {
    start = each.value.pool_start
    end   = each.value.pool_end
  }
}
