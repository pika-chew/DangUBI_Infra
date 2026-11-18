# 생성·운영에서도 참조하는 기존 프로젝트, 이미지, Flavor의 UUID를 조회합니다.
# data는 조회만 수행하며 해당 자원을 Terraform 관리 대상으로 인수하지 않습니다.
data "openstack_identity_project_v3" "projects" {
  for_each = var.project_names

  name      = each.value
  domain_id = var.project_domain_id
}

data "openstack_images_image_v2" "ubuntu" {
  name = var.ubuntu_image_name

  # 최신 이미지를 자동 선택하면 기존 VM 교체로 이어질 수 있어 중복 이름은 오류로 처리합니다.
  most_recent = false
}

data "openstack_compute_flavor_v2" "flavors" {
  for_each = var.flavor_names

  name = each.value
}
