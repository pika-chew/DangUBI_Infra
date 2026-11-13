variable "import_ids" {
  description = "Horizon에 표시된 리소스 이름별 기존 UBI OpenStack 리소스의 UUID입니다."
  type = object({
    instances = object({
      jenkins-vm       = string
      observability-vm = string
      k8s-control-1    = string
      k8s-control-2    = string
      k8s-control-3    = string
      k8s-worker-1     = string
      k8s-worker-2     = string
      k8s-worker-3     = string
      k8s-worker-4     = string
    })
    networks = object({
      ext-net = string
      k8s-net = string
      ops-net = string
    })
    subnets = object({
      ext-subnet = string
      k8s-subnet = string
      ops-subnet = string
    })
  })

  validation {
    condition = alltrue([
      for id in concat(values(var.import_ids.instances), values(var.import_ids.networks), values(var.import_ids.subnets)) :
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", id))
    ])
    error_message = "Enter the OpenStack UUID for each resource in import_ids."
  }

  validation {
    condition = alltrue([
      for ids in [values(var.import_ids.instances), values(var.import_ids.networks), values(var.import_ids.subnets)] :
      length(distinct([for id in ids : lower(id) if id != null])) == length(ids)
    ])
    error_message = "Each resource of the same type must have a different UUID."
  }
}
