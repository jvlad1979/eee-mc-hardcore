#!/usr/bin/env python3
import os
import re
import socket
import struct
import time

class RCONClient:
    def __init__(self, host, port, password):
        self.host = host
        self.port = port
        self.password = password
        self.sock = None
        self.request_id = 0

    def connect(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(5)
        self.sock.connect((self.host, self.port))
        self._send(3, self.password)
        resp_id, resp_type, _ = self._recv()
        if resp_id == -1:
            raise Exception("RCON Authentication failed")

    def disconnect(self):
        if self.sock:
            self.sock.close()
            self.sock = None

    def command(self, cmd):
        if not self.sock:
            self.connect()
        try:
            self._send(2, cmd)
            resp_id, resp_type, payload = self._recv()
            return payload
        except Exception as e:
            self.disconnect()
            raise e

    def _send(self, type, payload):
        self.request_id += 1
        data = struct.pack("<ii", self.request_id, type) + payload.encode("utf-8") + b"\x00\x00"
        length = struct.pack("<i", len(data))
        self.sock.sendall(length + data)

    def _recv(self):
        length_data = self.sock.recv(4)
        if not length_data:
            raise Exception("RCON connection closed")
        length = struct.unpack("<i", length_data)[0]
        data = self.sock.recv(length)
        if len(data) < length:
            data += self.sock.recv(length - len(data))
        resp_id, resp_type = struct.unpack("<ii", data[:8])
        payload = data[8:-2].decode("utf-8")
        return resp_id, resp_type, payload

WORLDS_FILE = "/data/plugins/Multiverse-Core/worlds.yml"
GROUPS_FILE = "/data/plugins/Multiverse-Inventories/groups.yml"
RCON_HOST = os.environ.get("RCON_HOST", "mc")
RCON_PORT = int(os.environ.get("RCON_PORT", "25575"))
RCON_PASS = os.environ.get("RCON_PASS", "minecraft")

def get_survival_groups():
    groups = set()
    if not os.path.exists(WORLDS_FILE): return groups
    with open(WORLDS_FILE, "r") as f:
        content = f.read()
        matches = re.findall(r"survival_g_([a-zA-Z0-9_\-]+):", content)
        for m in matches:
            base_id = re.sub(r"_(nether|the_end|end)$", "", m)
            groups.add(base_id)
    return groups

def update_groups(target_groups):
    if not os.path.exists(GROUPS_FILE): return False
    with open(GROUPS_FILE, "r") as f:
        lines = f.readlines()
    content = "".join(lines)
    changed = False

    # Ensure baseline vanilla group exists
    if "hardcore_vanilla" not in content:
        print("Adding hardcore_vanilla baseline group")
        lines.append("\n  hardcore_vanilla:\n    worlds:\n    - survival_vanilla\n    - survival_vanilla_nether\n    - survival_vanilla_the_end\n    shares:\n    - all\n")
        changed = True

    for g in target_groups:
        group_key = f"hardcore_{g}"
        if group_key not in content:
            print(f"Adding inventory group for: {g}")
            new_entry = [f"  {group_key}:\n", f"    worlds:\n", f"    - survival_g_{g}\n", f"    - survival_g_{g}_nether\n", f"    - survival_g_{g}_the_end\n", f"    shares:\n", f"    - all\n"]
            if not lines[-1].endswith("\n"): lines.append("\n")
            lines.extend(new_entry)
            content = "".join(lines)
            changed = True
    if changed:
        with open(GROUPS_FILE, "w") as f: f.writelines(lines)
        return True
    return False

def main():
    print(f"Starting Multiverse-Inventories Sync Sidecar (Target: {RCON_HOST}:{RCON_PORT})...")
    rcon = RCONClient(RCON_HOST, RCON_PORT, RCON_PASS)
    while True:
        try:
            groups = get_survival_groups()
            if update_groups(groups):
                print("Groups updated. Triggering Multiverse-Inventories reload...")
                rcon.command("mvinv reload")
        except Exception as e:
            print(f"Error in sync loop: {e}")
            rcon.disconnect()
        time.sleep(10)

if __name__ == "__main__":
    main()
