# ===========================================
# Ansible - Dynamic Inventory Script (GCP)
# ===========================================

#!/usr/bin/env python3
"""
Dynamic Ansible Inventory for GCP
Generates inventory from GCP Compute Instances

Usage:
    ansible-inventory -i gcp_compute.py --list
    ansible-inventory -i gcp_compute.py --host <hostname>
"""

import json
import subprocess
import sys


def get_gcp_instances():
    """Get Odoo instances from GCP using gcloud CLI"""
    try:
        result = subprocess.run(
            [
                "gcloud", "compute", "instances", "list",
                "--filter=name:odoo*",
                "--format=json"
            ],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
        return []
    except Exception as e:
        print(f"Error getting instances: {e}", file=sys.stderr)
        return []


def build_inventory():
    """Build Ansible inventory structure"""
    instances = get_gcp_instances()
    
    inventory = {
        "all": {
            "hosts": {},
            "children": {
                "odoo_servers": {
                    "hosts": {}
                }
            },
            "vars": {
                "ansible_python_interpreter": "/usr/bin/python3"
            }
        },
        "_meta": {
            "hostvars": {}
        }
    }

    for instance in instances:
        name = instance.get("name", "")
        network_interface = instance.get("networkInterfaces", [{}])[0]
        access_config = network_interface.get("accessConfigs", [{}])[0]
        ip = access_config.get("natIP", "")
        
        if ip and name:
            inventory["all"]["hosts"][name] = {
                "ansible_host": ip,
                "odoo_instance_name": name
            }
            inventory["all"]["children"]["odoo_servers"]["hosts"][name] = None
            inventory["_meta"]["hostvars"][name] = {
                "ansible_host": ip,
                "gcp_zone": instance.get("zone", "").split("/")[-1],
                "gcp_machine_type": instance.get("machineType", "").split("/")[-1]
            }

    return inventory


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--list":
        print(json.dumps(build_inventory(), indent=2))
    elif len(sys.argv) > 2 and sys.argv[1] == "--host":
        inventory = build_inventory()
        host = sys.argv[2]
        print(json.dumps(inventory.get("_meta", {}).get("hostvars", {}).get(host, {}), indent=2))
    else:
        print("Usage: ansible-inventory -i gcp_compute.py --list")
