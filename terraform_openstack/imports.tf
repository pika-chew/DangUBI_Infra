import {
  to = openstack_compute_instance_v2.jenkins_vm
  id = var.import_ids.instances["jenkins-vm"]
}

import {
  to = openstack_compute_instance_v2.observability_vm
  id = var.import_ids.instances["observability-vm"]
}

import {
  to = openstack_compute_instance_v2.k8s_control_1
  id = var.import_ids.instances["k8s-control-1"]
}

import {
  to = openstack_compute_instance_v2.k8s_control_2
  id = var.import_ids.instances["k8s-control-2"]
}

import {
  to = openstack_compute_instance_v2.k8s_control_3
  id = var.import_ids.instances["k8s-control-3"]
}

import {
  to = openstack_compute_instance_v2.k8s_worker_1
  id = var.import_ids.instances["k8s-worker-1"]
}

import {
  to = openstack_compute_instance_v2.k8s_worker_2
  id = var.import_ids.instances["k8s-worker-2"]
}

import {
  to = openstack_compute_instance_v2.k8s_worker_3
  id = var.import_ids.instances["k8s-worker-3"]
}

import {
  to = openstack_compute_instance_v2.k8s_worker_4
  id = var.import_ids.instances["k8s-worker-4"]
}

import {
  to = openstack_networking_network_v2.ext_net
  id = var.import_ids.networks["ext-net"]
}

import {
  to = openstack_networking_network_v2.k8s_net
  id = var.import_ids.networks["k8s-net"]
}

import {
  to = openstack_networking_network_v2.ops_net
  id = var.import_ids.networks["ops-net"]
}

import {
  to = openstack_networking_subnet_v2.ext_subnet
  id = var.import_ids.subnets["ext-subnet"]
}

import {
  to = openstack_networking_subnet_v2.k8s_subnet
  id = var.import_ids.subnets["k8s-subnet"]
}

import {
  to = openstack_networking_subnet_v2.ops_subnet
  id = var.import_ids.subnets["ops-subnet"]
}
