locals {
  # Horizon에서 확인한 사용자 정의 보안 그룹입니다. 각 그룹의 설명은 이름과 같습니다.
  security_group_names = toset(["sg-argocd", "sg-jenkins", "sg-k8s", "sg-obs", "sg-ssh", "sg-vault"])
}

resource "openstack_networking_secgroup_v2" "groups" {
  for_each = local.security_group_names

  name        = each.key
  description = each.key
  tenant_id   = var.project_ids.ubi

  # 규칙 전체를 코드로 정의한 그룹은 신규 생성 시 자동 규칙을 비워 중복을 피합니다.
  delete_default_rules = contains(keys(local.security_group_ingress_rules), each.key) ? true : null

  lifecycle {
    # Provider가 인수 시 이 생성 옵션을 읽어 오지 않아 기존 그룹 교체를 방지합니다.
    ignore_changes = [delete_default_rules]
  }
}

# 루트의 import 조회에서 동일한 그룹 이름 목록을 사용합니다.
output "security_group_names" {
  value = local.security_group_names
}
