variable "project_ids" {
  description = "외부 네트워크와 UBI 내부 네트워크를 소유하는 프로젝트의 ID입니다."
  type = object({
    external = string
    ubi      = string
  })
}
