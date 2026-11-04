"""Read-only CCM discovery check. Credentials enter via stdin and never leave it."""

import json
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def check(config):
    def request(url, data=None, token=None):
        headers = {"Content-Type": "application/json"}
        if token:
            headers["X-Auth-Token"] = token
        payload = json.dumps(data).encode() if data is not None else None
        with urlopen(Request(url, data=payload, headers=headers), timeout=10) as response:
            return json.load(response), response.headers

    auth_url = config["auth_url"].rstrip("/")
    if not auth_url.endswith("/v3"):
        auth_url += "/v3"
    body, headers = request(auth_url + "/auth/tokens", {
        "auth": {"identity": {"methods": ["application_credential"],
                             "application_credential": {"id": config["credential_id"],
                                                        "secret": config["secret"]}}}
    })
    identity = body["token"]
    if identity["project"]["id"] != config["project_id"]:
        raise ValueError("credential project mismatch")
    token = headers["X-Subject-Token"]

    def endpoint(service_type):
        urls = [ep["url"].rstrip("/") for service in identity["catalog"]
                if service["type"] == service_type for ep in service["endpoints"]
                if ep.get("region") == config["region"] and ep["interface"] == "public"]
        if len(urls) != 1:
            raise ValueError("expected one regional public endpoint")
        return urls[0]

    compute = endpoint("compute")
    network = endpoint("network")
    if not network.endswith("/v2.0"):
        network += "/v2.0"

    servers = []
    url = compute + "/servers/detail"
    while url:
        page, _ = request(url, token=token)
        servers.extend(page["servers"])
        url = next((link["href"] for link in page.get("servers_links", [])
                    if link["rel"] == "next"), None)

    result = {}
    checked_flavors = set()
    for name, address in config["nodes"].items():
        matches = [server for server in servers if server["name"] == name]
        if len(matches) != 1:
            raise ValueError("VM name must resolve uniquely")
        server_id = matches[0]["id"]
        detail, _ = request(compute + "/servers/" + server_id, token=token)
        flavor = detail["server"]["flavor"]
        if "id" in flavor and flavor["id"] not in checked_flavors:
            request(compute + "/flavors/" + flavor["id"], token=token)
            checked_flavors.add(flavor["id"])
        ports, _ = request(network + "/ports?" + urlencode({"device_id": server_id}), token=token)
        if not any(port["status"] == "ACTIVE" and any(ip["ip_address"] == address
                   for ip in port["fixed_ips"]) for port in ports["ports"]):
            raise ValueError("VM active port IP does not match inventory")
        result[name] = "openstack:///" + server_id
    return result


if __name__ == "__main__":
    try:
        print(json.dumps(check(json.load(sys.stdin))))
    except HTTPError as error:
        sys.exit(f"OpenStack read check failed: HTTP {error.code}")
    except (URLError, TimeoutError):
        sys.exit("OpenStack read check failed: connection error or timeout")
    except (KeyError, TypeError, ValueError):
        sys.exit("OpenStack read check failed: project, catalog, VM, flavor or port mismatch")
