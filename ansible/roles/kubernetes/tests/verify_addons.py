"""Exercise addon rendering, cloud discovery failures and network-check cleanup offline."""

import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch
from urllib.error import HTTPError

sys.dont_write_bytecode = True
ROLE = Path(__file__).resolve().parents[1]
ANSIBLE = ROLE.parents[1]


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


cloud = load_module("openstack_check", ROLE / "preflight/files/openstack_check.py")
nodes = load_module("check_nodes", ROLE / "verify/files/check_nodes.py")
config = {"auth_url": "http://cloud:5000", "region": "RegionOne", "project_id": "project",
          "credential_id": "test-id", "secret": "test-secret", "nodes": {"worker1": "192.0.2.21"}}


class Response(io.BytesIO):
    def __init__(self, body, headers=None):
        super().__init__(json.dumps(body).encode())
        self.headers = headers or {}


def cloud_responses(project="project", duplicate=False, port_ip="192.0.2.21"):
    return [Response({"token": {"project": {"id": project}, "catalog": [
        {"type": kind, "endpoints": [{"region": "RegionOne", "interface": "public", "url": url}]}
        for kind, url in [("compute", "http://cloud:8774/v2.1"), ("network", "http://cloud:9696")]
    ]}}, {"X-Subject-Token": "test-token"}),
        Response({"servers": [{"name": "worker1", "id": "vm-id"}] * (2 if duplicate else 1)}),
        Response({"server": {"flavor": {"id": "flavor-id"}}}), Response({"flavor": {}}),
        Response({"ports": [{"status": "ACTIVE", "fixed_ips": [{"ip_address": port_ip}]}]})]


with patch.object(cloud, "urlopen", side_effect=cloud_responses()) as opened:
    assert cloud.check(config) == {"worker1": "openstack:///vm-id"}
    assert opened.call_args_list[-1].args[0].full_url == "http://cloud:9696/v2.0/ports?device_id=vm-id"
for changes in [{"project": "wrong"}, {"duplicate": True}, {"port_ip": "192.0.2.99"}]:
    with patch.object(cloud, "urlopen", side_effect=cloud_responses(**changes)):
        try:
            cloud.check(config)
        except ValueError:
            pass
        else:
            raise AssertionError(f"accepted invalid cloud response: {changes}")
responses = cloud_responses()
responses[-1] = HTTPError("http://cloud:9696/v2.0/ports", 403, "Forbidden", {}, None)
with patch.object(cloud, "urlopen", side_effect=responses):
    try:
        cloud.check(config)
    except HTTPError as error:
        assert error.code == 403
    else:
        raise AssertionError("Neutron authorization failure was ignored")
print("PASS: cloud discovery checks project, unique VM, flavor and active Neutron port access")

node = {"metadata": {"name": "worker1"}, "spec": {"providerID": "openstack:///vm-id"},
        "status": {"conditions": [{"type": "Ready", "status": "True"}],
                   "addresses": [{"type": "InternalIP", "address": "192.0.2.21"}]}}
state = {"nodes": {"items": [node]}, "expected": config["nodes"],
         "provider_ids": {"worker1": "openstack:///vm-id"}}
assert nodes.check(state).startswith("PASS")
for change in ["unready", "wrong_ip", "wrong_vm", "uninitialized", "missing"]:
    invalid = copy.deepcopy(state)
    current = invalid["nodes"]["items"][0]
    if change == "unready":
        current["status"]["conditions"][0]["status"] = "False"
    elif change == "wrong_ip":
        current["status"]["addresses"][0]["address"] = "198.51.100.1"
    elif change == "wrong_vm":
        current["spec"]["providerID"] = "openstack:///another-vm"
    elif change == "uninitialized":
        current["spec"]["taints"] = [{"key": "node.cloudprovider.kubernetes.io/uninitialized"}]
    else:
        invalid["nodes"]["items"] = []
    try:
        nodes.check(invalid)
    except ValueError:
        pass
    else:
        raise AssertionError(f"accepted invalid node state: {change}")
print("PASS: Ready alone cannot hide wrong VM identity, wrong IP or uninitialized cloud taint")


with tempfile.TemporaryDirectory(prefix="ubi-addon-verify-") as directory:
    temp = Path(directory)
    inventory = temp / "inventory.json"
    inventory.write_text(json.dumps({"all": {"children": {"kubernetes_workers": {
        "hosts": {f"worker{i}": {} for i in range(1, 5)}}}}}))
    env = dict(os.environ, ANSIBLE_LOCAL_TEMP=str(temp / "ansible-tmp"))
    variables = {
        "kubernetes_version": "1.36.5", "kubernetes_cni": "calico", "kubernetes_calico_version": "v3.33.0",
        "kubernetes_calico_dataplane": "Iptables", "kubernetes_calico_encapsulation": "VXLAN",
        "kubernetes_calico_bgp": "Disabled", "kubernetes_calico_mtu": 1400, "kubernetes_nic_mtu": 1450,
        "kubernetes_ccm_version": "v1.36.0", "kubernetes_external_cloud_provider": True,
        "kubernetes_openstack_auth_url": "http://cloud:5000", "kubernetes_openstack_region": "RegionOne",
        "kubernetes_openstack_project_id": "project", "kubernetes_openstack_internal_network": "k8s-net",
        "kubernetes_openstack_application_credential_id": "test-id",
        "kubernetes_openstack_application_credential_secret": 'test-"secret\\value',
        "kubernetes_api_vip": "192.0.2.10", "kubernetes_api_lb_port": 16443,
        "kubernetes_pod_cidr": "10.244.0.0/16", "kubernetes_addon_timeout": 60,
        "kubernetes_network_check_image": "docker.io/library/busybox:1.37.0",
        "kubernetes_network_namespace": "dangubi-network-check-test",
    }
    playbook = temp / "play.json"

    def run(tasks, extra=None, success=True, environment=None):
        playbook.write_text(json.dumps([{"hosts": "localhost", "connection": "local", "become": False,
                                         "gather_facts": False, "vars": variables | (extra or {}),
                                         "environment": environment or {}, "tasks": tasks}]))
        result = subprocess.run(["ansible-playbook", "-i", str(inventory), str(playbook)],
                                cwd=ANSIBLE, env=env, capture_output=True, text=True)
        if (result.returncode == 0) != success:
            raise AssertionError(result.stdout + result.stderr)
        return result

    tasks = []
    for source, target, role in [("calico/templates/installation.yml.j2", "calico.json", "calico"),
                                 ("ccm/templates/ccm.yml.j2", "ccm.json", "ccm"),
                                 ("verify/templates/network-check.yml.j2", "network.json", "verify")]:
        tasks.append({"ansible.builtin.copy": {"dest": str(temp / target), "mode": "0600",
                      "content": "{{ lookup('ansible.builtin.template', '" + str(ROLE / source) + "') | from_yaml_all | list | to_json }}"},
                      "vars": {"role_path": str(ROLE / role)}})
    tasks.extend([
        {"ansible.builtin.copy": {"dest": str(temp / "guards.json"), "mode": "0600",
         "content": "{{ (lookup('file', '" + str(ROLE / "preflight/tasks/addons.yml") + "') | from_yaml)[:2] | to_json }}"}},
        {"ansible.builtin.copy": {"dest": str(temp / "network-tasks.json"), "mode": "0600",
         "content": "{{ lookup('file', '" + str(ROLE / "verify/tasks/network.yml") + "') | from_yaml | to_json }}"}},
    ])
    offline = "--offline" in sys.argv
    if offline:
        # 로컬 RPC 소켓이 금지된 환경에서도 실제 Ansible 템플릿 엔진으로 검증합니다.
        import yaml
        from ansible.parsing.dataloader import DataLoader
        from ansible.plugins.loader import init_plugin_loader
        from ansible.template import Templar, trust_as_template
        init_plugin_loader()
        loader = DataLoader()
        group_vars = {"groups": {"kubernetes_workers": [f"worker{i}" for i in range(1, 5)]}}

        def render(value, extra=None):
            templar = Templar(loader=loader, variables=variables | group_vars | (extra or {}))
            return templar.template(trust_as_template(value))

        for source, target, role in [("calico/templates/installation.yml.j2", "calico.json", "calico"),
                                     ("ccm/templates/ccm.yml.j2", "ccm.json", "ccm"),
                                     ("verify/templates/network-check.yml.j2", "network.json", "verify")]:
            rendered = render((ROLE / source).read_text(), {"role_path": str(ROLE / role)})
            (temp / target).write_text(json.dumps(list(yaml.safe_load_all(rendered))))
        for source, target in [("preflight/tasks/addons.yml", "guards.json"),
                               ("verify/tasks/network.yml", "network-tasks.json")]:
            content = yaml.safe_load((ROLE / source).read_text())
            (temp / target).write_text(json.dumps(content[:2] if target == "guards.json" else content))
    else:
        run(tasks)
    installation = json.loads((temp / "calico.json").read_text())[0]["spec"]["calicoNetwork"]
    assert installation["linuxDataplane"] == "Iptables" and installation["bgp"] == "Disabled"
    assert installation["ipPools"][0]["encapsulation"] == "VXLAN"
    assert installation["ipPools"][0]["cidr"] == variables["kubernetes_pod_cidr"]
    assert installation["mtu"] == 1400
    ccm = json.loads((temp / "ccm.json").read_text())
    pod = ccm[-1]["spec"]["template"]["spec"]
    args = pod["containers"][0]["args"]
    assert "--controllers=cloud-node,cloud-node-lifecycle" in args
    assert "--configure-cloud-routes=false" in args and pod["hostNetwork"]
    assert {t["key"] for t in pod["tolerations"]} >= {"node.cloudprovider.kubernetes.io/uninitialized", "node-role.kubernetes.io/control-plane"}
    assert pod["volumes"][0]["secret"]["defaultMode"] == 0o440
    assert "test-id" not in (temp / "ccm.json").read_text()
    network = json.loads((temp / "network.json").read_text())
    assert len(network) == 5 and network[0]["kind"] == "Service"
    assert [p["spec"]["affinity"]["nodeAffinity"]["requiredDuringSchedulingIgnoredDuringExecution"]["nodeSelectorTerms"][0]["matchFields"][0]["values"][0]
            for p in network[1:]] == [f"worker{i}" for i in range(1, 5)]
    guard_tasks = [{"ansible.builtin.include_tasks": str(temp / "guards.json")}]
    for changes, success in [({}, True), ({"kubernetes_calico_mtu": 1450}, False),
                              ({"kubernetes_ccm_version": "v1.35.0"}, False),
                              ({"kubernetes_openstack_application_credential_secret": ""}, False),
                              ({"kubernetes_openstack_application_credential_secret": "line1\nline2"}, False)]:
        if offline:
            guards = json.loads((temp / "guards.json").read_text())
            conditions = [condition for task in guards for condition in task['ansible.builtin.assert']['that']]
            assert all(render('{{ (' + condition + ') }}', changes) for condition in conditions) == success, changes
        else:
            run(guard_tasks, changes, success)
    print("PASS: addon templates preserve VXLAN/MTU and node-only CCM; preflight rejects missing credentials and invalid inputs")

    if offline:
        network_tasks = json.loads((temp / "network-tasks.json").read_text())
        probes = [{'metadata': {'name': f'network-check-{i}'}, 'spec': {'nodeName': f'worker{i}'},
                   'status': {'podIP': f'10.244.{i}.1'}} for i in range(1,5)]
        command = network_tasks[-1]['block'][-1]['ansible.builtin.command']['argv']
        argv = render(command, {'item': probes[0], 'kubernetes_network_pods': {'stdout': json.dumps({'items': probes})}})
        assert argv[-4:] == [f'10.244.{i}.1' for i in range(1,5)]
        assert 'nslookup kubernetes.default.svc.cluster.local' in argv[10]
        assert network_tasks[-1]['always'][0]['ansible.builtin.command']['argv'][3:5] == ['delete', 'namespace']
        print('PASS: worker probe argv renders with all four Pod IPs and cleanup is in always')
        print('SKIP: Ansible task execution/cleanup integration requires a local RPC socket; offline checks only')
        sys.exit(0)

    # 본래 network role을 실행하되 kubectl만 대체해 실제 실패 때도 Namespace가 삭제되는지 검사합니다.
    fake = temp / "kubectl"
    fake.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
if 'create' in args and '-o' in args:
    print(json.dumps({'metadata': {'name': 'dangubi-network-check-test'}}))
elif 'create' in args:
    sys.stdin.read()
elif 'get' in args:
    print(json.dumps({'items': [{'metadata': {'name': f'network-check-{i}'},
        'spec': {'nodeName': f'worker{i}'}, 'status': {'podIP': f'10.244.{i}.1'}} for i in range(1,5)]}))
elif 'exec' in args and os.environ.get('FAKE_NETWORK_FAIL') == '1':
    sys.exit(1)
elif 'delete' in args:
    pathlib.Path(os.environ['FAKE_CLEANUP']).write_text('deleted')
''')
    fake.chmod(0o700)
    network_tasks = json.loads((temp / "network-tasks.json").read_text())
    for task in network_tasks[-1]["block"]:
        if "retries" in task:
            task.update(retries=0, delay=0)
    for fail in (False, True):
        cleanup = temp / f"cleanup-{fail}"
        result = run(network_tasks, success=not fail, environment={
            "PATH": str(temp) + ":" + os.environ["PATH"], "FAKE_CLEANUP": str(cleanup),
            "FAKE_NETWORK_FAIL": "1" if fail else "0"})
        assert cleanup.read_text() == "deleted"
    print("PASS: network probe success and failure both delete their temporary Namespace")
