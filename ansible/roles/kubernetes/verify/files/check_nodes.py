"""Validate inventory nodes without accepting Ready as proof of CCM initialization."""

import json
import subprocess
import sys


def check(config):
    nodes = {node["metadata"]["name"]: node for node in config["nodes"]["items"]}
    for name, address in config["expected"].items():
        if name not in nodes:
            raise ValueError(f"{name}: not registered")
        node = nodes[name]
        if not any(condition["type"] == "Ready" and condition["status"] == "True"
                   for condition in node.get("status", {}).get("conditions", [])):
            raise ValueError(f"{name}: not Ready")
        if not any(ip["type"] == "InternalIP" and ip["address"] == address
                   for ip in node.get("status", {}).get("addresses", [])):
            raise ValueError(f"{name}: InternalIP mismatch")
        if config["provider_ids"]:
            if node.get("spec", {}).get("providerID") != config["provider_ids"][name]:
                raise ValueError(f"{name}: OpenStack VM identity mismatch")
            if any(taint["key"] == "node.cloudprovider.kubernetes.io/uninitialized"
                   for taint in node.get("spec", {}).get("taints", [])):
                raise ValueError(f"{name}: CCM initialization incomplete")
    return "PASS: all inventory nodes Ready with expected addresses and cloud identities"


if __name__ == "__main__":
    try:
        config = json.load(sys.stdin)
        config['nodes'] = json.loads(subprocess.check_output(
            ['kubectl', '--kubeconfig', '/etc/kubernetes/admin.conf', 'get', 'nodes', '-o', 'json'],
            text=True, timeout=30))
        print(check(config))
    except (subprocess.SubprocessError, OSError):
        sys.exit('Could not read current Kubernetes node state')
    except (KeyError, TypeError, ValueError) as error:
        sys.exit(str(error))
