"""Verify bootstrap guards and render configuration without contacting any VM."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib


ANSIBLE = Path(__file__).resolve().parents[3]
ROLE = ANSIBLE / "roles/kubernetes"


def run(playbook, inventory, env, expect_success=True):
    result = subprocess.run(
        ["ansible-playbook", "-i", str(inventory), str(playbook)],
        cwd=ANSIBLE, env=env, text=True, capture_output=True,
    )
    if (result.returncode == 0) != expect_success:
        raise AssertionError(result.stdout + result.stderr)
    return result


with tempfile.TemporaryDirectory(prefix="ubi-kubernetes-verify-") as directory:
    temp = Path(directory)
    env = dict(os.environ, ANSIBLE_LOCAL_TEMP=str(temp / "ansible-tmp"))
    inventory = temp / "inventory.json"
    inventory.write_text(json.dumps({"all": {"children": {
        "kubernetes": {"children": {
            "kubernetes_control_plane": {"hosts": {}},
            "kubernetes_workers": {"hosts": {}},
        }},
    }}}))
    result = run(ANSIBLE / "playbooks/kubernetes/site.yml", inventory, env, False)
    assert "VM 7대의 inventory" in result.stdout + result.stderr, result.stdout + result.stderr
    print("PASS: empty inventory fails before node configuration")

    control_planes = {f"cp{i}": {"kubernetes_node_ip": f"192.0.2.{i}"} for i in range(1, 4)}
    inventory.write_text(json.dumps({"all": {"children": {
        "kubernetes_control_plane": {"hosts": control_planes},
        "kubernetes_workers": {"hosts": {f"worker{i}": {} for i in range(1, 5)}},
    }}}))
    # 정적 파일 검사 외에 Ansible 자체로 추가 CP 대상이 cp2·cp3인지 확인합니다.
    listed = subprocess.run(
        ["ansible-playbook", "-i", str(inventory), "playbooks/kubernetes/site.yml", "--list-hosts"],
        cwd=ANSIBLE, env=env, text=True, capture_output=True, check=True,
    )
    secondary = listed.stdout.split("Join additional control planes", 1)[1].split("play #", 1)[0]
    assert "cp2" in secondary and "cp3" in secondary and "cp1" not in secondary, secondary
    print("PASS: Ansible selects only secondary control planes for sequential join")
    variables = {
        "kubernetes_version": "1.35.1",
        "kubernetes_api_endpoint": "192.0.2.10:16443",
        "kubernetes_api_cert_sans": ["198.51.100.10"],
        "kubernetes_node_ip": "192.0.2.1",
        "kubernetes_physical_host": "ctl1",
        "kubernetes_cri_socket": "unix:///run/containerd/containerd.sock",
        "kubernetes_pod_cidr": "10.244.0.0/16",
        "kubernetes_service_cidr": "10.96.0.0/12",
        "kubernetes_external_cloud_provider": True,
        "kubernetes_join_token_ttl": "15m",
        "kubernetes_join_token": {"stdout": "abcdef.0123456789abcdef"},
        "kubernetes_ca_hash": {"stdout": "0" * 64},
        "kubernetes_certificate_key": {"stdout": "1" * 64},
        "kubernetes_interface": "ens3",
        "kubernetes_api_vip": "192.0.2.10",
        "kubernetes_api_vip_prefix": 24,
        "kubernetes_api_lb_port": 16443,
        "kubernetes_vrrp_router_id": 51,
        "kubernetes_images": {"stdout_lines": ["registry.k8s.io/pause:3.10"]},
    }
    tasks = []
    tasks.append({"name": "Read orchestration playbook", "ansible.builtin.set_fact": {
        "site": "{{ lookup('file', '" + str(ANSIBLE / "playbooks/kubernetes/site.yml") + "') | from_yaml }}",
    }})
    # role을 분리해도 첫 CP를 재가입시키지 않고, 패키지보다 검증을 먼저 실행해야 합니다.
    tasks.append({"name": "Validate role boundaries and bootstrap order", "ansible.builtin.assert": {"that": [
        "site | length == 7",
        "site | selectattr('pre_tasks', 'defined') | list | length == 0",
        "site | selectattr('tasks', 'defined') | list | length == 0",
        "site[0].roles == ['kubernetes/inventory']",
        "site[1].roles == ['kubernetes/preflight', 'kubernetes/common', 'kubernetes/packages', 'kubernetes/containerd']",
        "site[2].roles == ['kubernetes/api_lb']",
        "site[3].hosts == 'kubernetes_control_plane[0]'",
        "site[3].roles == ['kubernetes/control_plane']",
        "site[4].hosts == 'kubernetes_control_plane[1:]'",
        "site[4].serial == 1",
        "site[5].hosts == 'kubernetes_workers'",
        "site[5].serial == 1",
        "site[6].roles[0].role == 'kubernetes/ccm'",
        "site[6].roles[0].when == 'kubernetes_external_cloud_provider | bool'",
        "site[6].roles[1:] == ['kubernetes/calico', 'kubernetes/verify']",
    ]}})
    cases = [
        ("control_plane/templates/init.yml.j2", "init-external.yml", {"inventory_hostname": "cp1"}),
        ("control_plane/templates/init.yml.j2", "init-no-cloud.yml", {"inventory_hostname": "cp1", "kubernetes_external_cloud_provider": False}),
        ("join/templates/join.yml.j2", "join-cp.yml", {"inventory_hostname": "cp2"}),
        ("join/templates/join.yml.j2", "join-worker.yml", {"inventory_hostname": "worker1", "kubernetes_external_cloud_provider": False}),
        ("containerd/templates/containerd.toml.j2", "containerd1.toml", {"kubernetes_containerd_major": 1}),
        ("containerd/templates/containerd.toml.j2", "containerd2.toml", {"kubernetes_containerd_major": 2}),
        ("api_lb/templates/haproxy.cfg.j2", "haproxy.cfg", {}),
        ("api_lb/templates/keepalived.conf.j2", "keepalived.conf", {"inventory_hostname": "cp1"}),
    ]
    for source, target, case_vars in cases:
        tasks.append({"name": f"Render {target}", "ansible.builtin.template": {
            "src": str(ROLE / source), "dest": str(temp / target), "mode": "0600",
        }, "vars": case_vars})
    tasks.append({"name": "Read preflight tasks", "ansible.builtin.set_fact": {
        "preflight": "{{ lookup('file', '" + str(ROLE / "preflight/tasks/node.yml") + "') | from_yaml }}",
    }})
    tasks.append({"name": "Extract network validation program", "ansible.builtin.copy": {
        "dest": str(temp / "validate_network.py"), "mode": "0600",
        "content": "{{ preflight[1]['ansible.builtin.command']['argv'][2] }}",
    }})
    tasks.append({"name": "Extract configuration assertion", "ansible.builtin.copy": {
        "dest": str(temp / "assertion.json"), "mode": "0600",
        "content": "{{ [preflight[0]] | to_json }}",
    }})
    for name in ("init-external", "init-no-cloud", "join-cp", "join-worker"):
        tasks.append({"name": f"Parse {name}", "ansible.builtin.set_fact": {
            name.replace("-", "_"): "{{ lookup('file', '" + str(temp / (name + ".yml")) + "') | from_yaml_all | list }}",
        }})
    tasks.append({"name": "Validate kubeadm config structure", "ansible.builtin.assert": {"that": [
        "init_external | length == 3",
        "init_external[1].controlPlaneEndpoint == '192.0.2.10:16443'",
        "'198.51.100.10' in init_external[1].apiServer.certSANs",
        "init_external[2].cgroupDriver == 'systemd'",
        "init_external[0].nodeRegistration.kubeletExtraArgs | selectattr('name', 'equalto', 'cloud-provider') | list | length == 1",
        "init_no_cloud[0].nodeRegistration.kubeletExtraArgs | selectattr('name', 'equalto', 'cloud-provider') | list | length == 0",
        "join_cp[0].controlPlane.certificateKey | length == 64",
        "'controlPlane' not in join_worker[0]",
        "join_worker[0].discovery.bootstrapToken.caCertHashes[0] == 'sha256:' + '0' * 64",
    ]}})
    playbook = temp / "render.json"
    playbook.write_text(json.dumps([{"hosts": "localhost", "connection": "local", "become": False, "gather_facts": False,
                                     "vars": variables, "tasks": tasks}]))
    run(playbook, inventory, env)
    for major in (1, 2):
        config = tomllib.loads((temp / f"containerd{major}.toml").read_text())
        cri = "io.containerd.grpc.v1.cri" if major == 1 else "io.containerd.cri.v1.runtime"
        assert config["version"] == (2 if major == 1 else 3)
        assert config["plugins"][cri]["containerd"]["runtimes"]["runc"]["options"]["SystemdCgroup"]
    assert "cp3 192.0.2.3:6443" in (temp / "haproxy.cfg").read_text()
    assert "192.0.2.2" in (temp / "keepalived.conf").read_text()
    print("PASS: init/join, CCM on/off, containerd 1/2, API LB templates render and parse")

    base = {"node": "192.0.2.0/24", "pod": "10.244.0.0/16", "service": "10.96.0.0/12",
            "ip": "192.0.2.1", "endpoint": "192.0.2.10:16443", "managed_lb": True,
            "vip": "192.0.2.10", "lb_port": 16443, "vrid": 51, "prefix": 24}
    for changes, expected in [({}, True), ({"pod": "192.0.2.0/24"}, False),
                              ({"ip": "198.51.100.1"}, False), ({"vip": "192.0.2.20"}, False),
                              ({"endpoint": "192.0.2.10:6443", "lb_port": 6443}, False)]:
        result = subprocess.run(["python3", str(temp / "validate_network.py")],
                                input=json.dumps(base | changes), text=True, capture_output=True)
        assert (result.returncode == 0) == expected, result.stderr
    print("PASS: network guard rejects overlapping CIDRs, wrong node IP, VIP mismatch, port conflict")

    preflight_vars = variables | {
        "ansible_facts": {"distribution": "Ubuntu", "distribution_version": "24.04",
                          "service_mgr": "systemd", "processor_vcpus": 2, "memtotal_mb": 4096,
                          "interfaces": ["ens3"], "ens3": {"mtu": 1450, "ipv4": {"address": "192.0.2.1"}}},
        "inventory_hostname": "cp1", "kubernetes_nic_mtu": 1450,
        "kubernetes_manage_api_lb": False, "kubernetes_api_endpoint_ready": True,
        "kubernetes_package_version": "1.35.1-1.1", "kubernetes_containerd_package_version": "2.1.0-1",
    }
    for changes, expected in [({}, True), ({"kubernetes_version": ""}, False),
                              ({"kubernetes_external_cloud_provider": None}, False),
                              ({"kubernetes_nic_mtu": 1500}, False),
                              ({"kubernetes_api_endpoint_ready": False}, False)]:
        playbook.write_text(json.dumps([{"hosts": "localhost", "connection": "local", "become": False,
                                         "gather_facts": False, "vars": preflight_vars | changes,
                                         "tasks": [{"ansible.builtin.include_tasks": str(temp / "assertion.json")}]}]))
        result = run(playbook, inventory, env, expected)
        if not expected:
            assert "빈 변수로는 설치를 시작하지 않습니다" in result.stdout + result.stderr
    print("PASS: preflight rejects missing version/CCM choice, wrong MTU, unprepared external LB")

subprocess.run(["python3", str(ROLE / "tests/verify_addons.py")], check=True)
