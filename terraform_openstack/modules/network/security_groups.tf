locals {
  # Horizon에서 확인한 사용자 정의 보안 그룹입니다. 각 그룹의 설명은 이름과 같습니다.
  security_group_names = toset(["sg-argocd", "sg-jenkins", "sg-k8s", "sg-obs", "sg-ssh", "sg-vault"])
}

resource "openstack_networking_secgroup_v2" "groups" {
  for_each = local.security_group_names

  name        = each.key
  description = each.key
  tenant_id   = var.project_ids.ubi
}

# 루트의 import 조회에서 동일한 그룹 이름 목록을 사용합니다.
output "security_group_names" {
  value = local.security_group_names
}
