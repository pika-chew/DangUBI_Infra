# 실행은 이 폴더에서 합니다. 같은 폴더의 모든 .tf 파일을 함께 읽습니다.
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.4.0"
    }
  }
}

# 인증과 리전은 OpenRC의 OS_* 환경 변수 또는 OS_CLOUD 설정에서 읽습니다.
provider "openstack" {}

module "compute" {
  source = "./modules/compute"

  # 생성·운영에 필요한 이미지와 Flavor는 이름으로 조회하며 import 여부와 무관합니다.
  ubuntu_image_id          = data.openstack_images_image_v2.ubuntu.id
  observability_flavor_id  = data.openstack_compute_flavor_v2.flavors["observability"].id
  vault_flavor_id          = data.openstack_compute_flavor_v2.flavors["vault"].id
  jenkins_flavor_id        = data.openstack_compute_flavor_v2.flavors["jenkins"].id
  k8s_control_flavor_id    = data.openstack_compute_flavor_v2.flavors["k8s_control"].id
  k8s_worker_flavor_id     = data.openstack_compute_flavor_v2.flavors["k8s_worker"].id
  k8s_worker_cmp_flavor_id = data.openstack_compute_flavor_v2.flavors["k8s_worker_cmp"].id
}
