# 하위 모듈도 Provider 출처를 선언해야 합니다. 버전 선택과 인증은 루트에서 관리합니다.
terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}
