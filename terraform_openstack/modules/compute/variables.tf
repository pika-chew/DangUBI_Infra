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
