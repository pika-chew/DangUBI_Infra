output "ops_network_id" {
  description = "컴퓨팅 모듈에서 참조하는 기존 ops-net의 UUID입니다."
  value       = openstack_networking_network_v2.networks["ops-net"].id
}
