locals {
  # Neutron 기본 송신 규칙은 원격 CIDR을 생략하면 해당 IP 버전 전체를 허용합니다.
  security_group_egress_rules = {
    "egress-ipv4" = { direction = "egress", ethertype = "IPv4" }
    "egress-ipv6" = { direction = "egress", ethertype = "IPv6" }
  }

  # Horizon에서 확인한 IPv4 수신 규칙입니다. port는 단일 목적지 포트입니다.
  security_group_ingress_rules = {
    "sg-argocd" = {
      "ingress-https-external" = {
        protocol         = "tcp"
        port             = 443
        remote_ip_prefix = "10.20.0.0/24"
      }
      "ingress-https-jenkins" = {
        protocol         = "tcp"
        port             = 443
        remote_ip_prefix = "172.16.20.10/32"
      }
    }
    "sg-jenkins" = {
      "ingress-http-external" = {
        protocol         = "tcp"
        port             = 8080
        remote_ip_prefix = "10.20.0.0/24"
      }
      "ingress-agent-k8s" = {
        protocol         = "tcp"
        port             = 50000
        remote_ip_prefix = "172.16.10.0/24"
      }
    }
    "sg-k8s" = {
      "ingress-k8s-subnet" = {
        remote_ip_prefix = "172.16.10.0/24"
      }
      "ingress-6443-ops" = {
        protocol         = "tcp"
        port             = 6443
        remote_ip_prefix = "172.16.20.0/24"
      }
      "ingress-6443-external" = {
        protocol         = "tcp"
        port             = 6443
        remote_ip_prefix = "10.20.0.0/24"
      }
      "ingress-8080-external" = {
        protocol         = "tcp"
        port             = 8080
        remote_ip_prefix = "10.20.0.0/24"
      }
      "ingress-9100-observability" = {
        protocol         = "tcp"
        port             = 9100
        remote_ip_prefix = "172.16.20.20/32"
      }
      "ingress-16443-ops" = {
        protocol         = "tcp"
        port             = 16443
        remote_ip_prefix = "172.16.20.0/24"
      }
      "ingress-16443-external" = {
        protocol         = "tcp"
        port             = 16443
        remote_ip_prefix = "10.20.0.0/24"
      }
    }
    "sg-obs" = {
      "ingress-grafana-external" = {
        protocol         = "tcp"
        port             = 3000
        remote_ip_prefix = "10.20.0.0/24"
      }
      "ingress-loki-10-20-0-5" = {
        protocol         = "tcp"
        port             = 3100
        remote_ip_prefix = "10.20.0.5/32"
        description      = "물리노드 -> Loki"
      }
      "ingress-loki-10-20-0-2" = {
        protocol         = "tcp"
        port             = 3100
        remote_ip_prefix = "10.20.0.2/32"
        description      = "물리노드 -> Loki"
      }
      "ingress-loki-vault" = {
        protocol         = "tcp"
        port             = 3100
        remote_ip_prefix = "172.16.20.30/32"
        description      = "vault-vm -> Loki"
      }
      "ingress-loki-10-20-0-3" = {
        protocol         = "tcp"
        port             = 3100
        remote_ip_prefix = "10.20.0.3/32"
        description      = "물리노드 -> Loki"
      }
      "ingress-loki-10-20-0-4" = {
        protocol         = "tcp"
        port             = 3100
        remote_ip_prefix = "10.20.0.4/32"
        description      = "물리노드 -> Loki"
      }
      "ingress-loki-k8s" = {
        protocol         = "tcp"
        port             = 3100
        remote_ip_prefix = "172.16.10.0/24"
        description      = "k8s -> Loki"
      }
      "ingress-loki-jenkins" = {
        protocol         = "tcp"
        port             = 3100
        remote_ip_prefix = "172.16.20.10/32"
        description      = "jenkins-vm -> Loki"
      }
      "ingress-prometheus-k8s" = {
        protocol         = "tcp"
        port             = 9090
        remote_ip_prefix = "172.16.10.0/24"
        description      = "k8s -> Prometheus"
      }
      "ingress-prometheus-external" = {
        protocol         = "tcp"
        port             = 9090
        remote_ip_prefix = "10.20.0.0/24"
      }
      "ingress-prometheus-vault" = {
        protocol         = "tcp"
        port             = 9090
        remote_ip_prefix = "172.16.20.30/32"
        description      = "vault-vm -> Promeheus"
      }
      "ingress-prometheus-jenkins" = {
        protocol         = "tcp"
        port             = 9090
        remote_ip_prefix = "172.16.20.10/32"
        description      = "jenkins-vm -> Prometheus"
      }
      "ingress-alertmanager-external" = {
        protocol         = "tcp"
        port             = 9093
        remote_ip_prefix = "10.20.0.0/24"
      }
    }
    "sg-ssh" = {
      "ingress-icmp" = {
        protocol         = "icmp"
        remote_ip_prefix = "10.20.0.0/24"
      }
      "ingress-ssh" = {
        protocol         = "tcp"
        port             = 22
        remote_ip_prefix = "10.20.0.0/24"
      }
    }
    "sg-vault" = {
      "ingress-8200-external" = {
        protocol         = "tcp"
        port             = 8200
        remote_ip_prefix = "10.20.0.0/24"
      }
      "ingress-8200-k8s" = {
        protocol     = "tcp"
        port         = 8200
        remote_group = "sg-k8s"
      }
    }
  }

  # 그룹 이름과 규칙 이름을 합쳐 클라우드 UUID에 의존하지 않는 주소를 사용합니다.
  security_group_rules_by_key = merge([
    for group_name, rules in local.security_group_ingress_rules : {
      for rule_name, rule in merge(local.security_group_egress_rules, rules) :
      "${group_name}/${rule_name}" => merge(rule, { group_name = group_name })
    }
  ]...)

  all_traffic_cidrs = { IPv4 = "0.0.0.0/0", IPv6 = "::/0" }
}

resource "openstack_networking_secgroup_rule_v2" "rules" {
  for_each = local.security_group_rules_by_key

  security_group_id = openstack_networking_secgroup_v2.groups[each.value.group_name].id
  tenant_id         = var.project_ids.ubi
  direction         = try(each.value.direction, "ingress")
  ethertype         = try(each.value.ethertype, "IPv4")
  protocol          = try(each.value.protocol, null)
  port_range_min    = try(each.value.port, null)
  port_range_max    = try(each.value.port, null)
  remote_ip_prefix  = try(each.value.remote_ip_prefix, null)
  description       = try(each.value.description, null)

  # Vault의 Kubernetes 접근 규칙은 CIDR 대신 sg-k8s에 속한 포트를 허용합니다.
  remote_group_id = try(each.value.remote_group, null) == null ? null : openstack_networking_secgroup_v2.groups[each.value.remote_group].id

  lifecycle {
    # Horizon은 원격 CIDR이 비어 있는 기본 규칙도 전체 CIDR로 표시합니다.
    # 두 표현을 허용하되 특정 CIDR이나 그룹으로 제한된 송신 상태는 감지합니다.
    postcondition {
      condition = self.direction != "egress" || (
        coalesce(self.remote_ip_prefix, local.all_traffic_cidrs[self.ethertype]) == local.all_traffic_cidrs[self.ethertype] &&
        (self.remote_group_id == null || self.remote_group_id == "") &&
        (self.remote_address_group_id == null || self.remote_address_group_id == "")
      )
      error_message = "${each.key} 규칙의 원격 범위가 코드에 정의된 전체 범위와 다릅니다."
    }
  }
}
