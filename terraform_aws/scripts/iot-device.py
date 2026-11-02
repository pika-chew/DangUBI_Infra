"""Prepare a local IoT private key/CSR, then export public AWS connection files."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
ROOT_CA_URL = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"


def prepare(device_id, thing_name):
    folder = ROOT / "certificates" / device_id
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(folder, 0o700)
    private_key = folder / "private-key.pem"
    csr = folder / "request.csr"
    if csr.exists() and not private_key.exists():
        raise RuntimeError("CSR exists without its private key. Restore the original key or use a new device ID.")
    if private_key.exists() and csr.exists():
        print(f"Keeping existing private key and CSR: {folder}")
        return

    if not private_key.exists():
        fd, temporary = tempfile.mkstemp(prefix=".private-key-", dir=folder)
        os.close(fd)
        temporary = Path(temporary)
        try:
            subprocess.run(
                ["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048", "-out", str(temporary)],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
            )
            # Exclusive install: never overwrite another preparation's private key.
            os.link(temporary, private_key)
        finally:
            temporary.unlink(missing_ok=True)

    if not csr.exists():
        fd, temporary = tempfile.mkstemp(prefix=".csr-", dir=folder)
        os.close(fd)
        temporary = Path(temporary)
        try:
            subprocess.run(
                ["openssl", "req", "-new", "-sha256", "-key", str(private_key), "-subj", f"/CN={thing_name}", "-out", str(temporary)],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
            )
            os.link(temporary, csr)
        finally:
            temporary.unlink(missing_ok=True)
    print(f"Created local private key and public CSR: {folder}")
    print("Terraform reads request.csr only. Keep private-key.pem on this device.")


def terraform_output(name):
    result = subprocess.run(
        ["terraform", "output", "-json", name],
        cwd=ROOT, check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout)


def write_private_file(path, content):
    fd, temporary = tempfile.mkstemp(prefix=".export-", dir=path.parent)
    temporary = Path(temporary)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as out:
            out.write(content)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def export_device(device_id):
    folder = ROOT / "certificates" / device_id
    if not (folder / "private-key.pem").is_file():
        raise RuntimeError("Prepare the local private key/CSR first.")
    connections = terraform_output("iot_device_connections")
    certificates = terraform_output("iot_device_certificates")
    if device_id not in connections or device_id not in certificates:
        raise RuntimeError("Device missing from Terraform outputs. Complete terraform apply for this device first.")

    root_ca = folder / "AmazonRootCA1.pem"
    if not root_ca.exists():
        with urllib.request.urlopen(ROOT_CA_URL, timeout=30) as response:
            ca_pem = response.read().decode("ascii")
        if "-----BEGIN CERTIFICATE-----" not in ca_pem:
            raise RuntimeError("Amazon Root CA download did not return a PEM certificate.")
        write_private_file(root_ca, ca_pem)

    write_private_file(folder / "certificate.pem", certificates[device_id])
    config = {
        **connections[device_id],
        "port": 8883,
        "privateKeyPath": "private-key.pem",
        "certificatePath": "certificate.pem",
        "caPath": "AmazonRootCA1.pem",
    }
    write_private_file(folder / "connection.json", json.dumps(config, indent=2) + "\n")
    print(f"Saved public certificate and MQTT connection settings: {folder}")


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare", "export"])
    parser.add_argument("device_id", nargs="?", default="vehicle-001")
    parser.add_argument("--thing-name", help="CSR subject name; default: ubi-dev-<device-id>")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", args.device_id):
        parser.error("device_id must be 1-64 letters, digits, underscores or hyphens, starting with a letter or digit")
    thing_name = args.thing_name or f"ubi-dev-{args.device_id}"
    if not re.fullmatch(r"[A-Za-z0-9:_-]{1,128}", thing_name):
        parser.error("Invalid thing name for CSR subject")
    try:
        if args.command == "prepare":
            prepare(args.device_id, thing_name)
        else:
            export_device(args.device_id)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"IoT device setup failed: {error}\n")


if __name__ == "__main__":
    main()
