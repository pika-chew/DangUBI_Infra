variable "import_existing" {
  description = "기존 리소스를 이름으로 조회하여 import할 때만 true로 설정합니다. 등록 후에는 false로 운영합니다."
  type        = bool
  default     = false
}

variable "project_domain_id" {
  description = "프로젝트 이름 검색 범위를 제한하는 Keystone 도메인 ID입니다. 기본 도메인의 ID는 default입니다."
  type        = string
  default     = "default"
}

variable "project_names" {
  description = "외부망과 내부망을 소유하는 기존 프로젝트 이름입니다. external은 코드 내부 키입니다."
  type = object({
    external = string
    ubi      = string
  })
  default = {
    external = "admin"
    ubi      = "ubi"
  }
}

variable "ubuntu_image_name" {
  description = "VM 10대가 사용하는 기존 Glance 이미지 이름입니다. 같은 이름의 이미지가 여럿이면 조회를 중단합니다."
  type        = string
  default     = "ubuntu 24.04"
}

variable "flavor_names" {
  description = "각 역할에 사용할 기존 Nova Flavor 이름입니다. Flavor 자체를 생성하거나 관리하지는 않습니다."
  type = object({
    observability  = string
    vault          = string
    jenkins        = string
    k8s_control    = string
    k8s_worker     = string
    k8s_worker_cmp = string
  })
  default = {
    observability  = "observability"
    vault          = "vault"
    jenkins        = "jenkins1"
    k8s_control    = "k8s-control"
    k8s_worker     = "k8s-worker"
    k8s_worker_cmp = "k8s-worker-cmp"
  }
}
