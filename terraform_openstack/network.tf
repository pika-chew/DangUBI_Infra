# Provider 인증은 루트에서 상속하며 compute 모듈과 같은 state에 기록합니다.
module "network" {
  source = "./modules/network"

  # external은 ext-net을 소유한 admin 프로젝트를 가리키는 코드 내부 키입니다.
  project_ids = { for key, project in data.openstack_identity_project_v3.projects : key => project.id }
}
