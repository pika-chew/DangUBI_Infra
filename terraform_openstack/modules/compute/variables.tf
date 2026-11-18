# 루트에서 전달받은 기존 이미지와 Flavor를 사용합니다. 해당 자원 자체는 이 모듈에서 생성하지 않습니다.
variable "ubuntu_image_id" {
  description = "인스턴스가 공통으로 사용하는 Ubuntu 24.04 Glance 이미지의 UUID입니다."
  type        = string
}

variable "observability_flavor_id" {
  description = "observability-vm이 사용하는 기존 Nova Flavor의 UUID입니다."
  type        = string
}

variable "vault_flavor_id" {
  description = "vault가 사용하는 기존 Nova Flavor의 UUID입니다."
  type        = string
}

variable "jenkins_flavor_id" {
  description = "jenkins-vm이 사용하는 기존 Nova Flavor의 UUID입니다."
  type        = string
}

variable "k8s_control_flavor_id" {
  description = "Kubernetes 컨트롤 플레인이 공통으로 사용하는 기존 Nova Flavor의 UUID입니다."
  type        = string
}

variable "k8s_worker_flavor_id" {
  description = "Kubernetes 워커 1~3이 사용하는 기존 Nova Flavor의 UUID입니다."
  type        = string
}

variable "k8s_worker_cmp_flavor_id" {
  description = "Kubernetes 워커 4가 사용하는 기존 Nova Flavor의 UUID입니다."
  type        = string
}
