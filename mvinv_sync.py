#!/usr/bin/env python3
import os
import re
import subprocess
import time

# Configuration
WORLDS_FILE = "data/plugins/Multiverse-Core/worlds.yml"
GROUPS_FILE = "data/plugins/Multiverse-Inventories/groups.yml"
RELOAD_CMD = ["docker", "exec", "mc-server-mc-1", "rcon-cli", "mvinv", "reload"]

def get_survival_groups():
    groups = set()
    if not os.path.exists(WORLDS_FILE):
        return groups
    
    with open(WORLDS_FILE, "r") as f:
        content = f.read()
        # Find survival_g_<id>:
        matches = re.findall(r"survival_g_([a-zA-Z0-9_\-]+):", content)
        for m in matches:
            # We want the base ID, not the _nether or _the_end parts
            base_id = re.sub(r"_(nether|the_end|end)$", "", m)
            groups.add(base_id)
    return groups

def update_groups(target_groups):
    if not os.path.exists(GROUPS_FILE):
        print(f"Error: {GROUPS_FILE} not found")
        return False

    with open(GROUPS_FILE, "r") as f:
        lines = f.readlines()

    content = "".join(lines)
    changed = False
    
    for g in target_groups:
        group_key = f"hardcore_{g}"
        if group_key not in content:
            print(f"Adding inventory group for: {g}")
            # Construct the new group entry
            new_entry = [
                f"  {group_key}:\n",
                f"    worlds:\n",
                f"    - survival_g_{g}\n",
                f"    - survival_g_{g}_nether\n",
                f"    - survival_g_{g}_the_end\n",
                f"    shares:\n",
                f"    - all\n"
            ]
            # Ensure we append to the end of the file or after 'groups:'
            # Since the file structure is simple, we just append to the end
            if not lines[-1].endswith("\n"):
                lines.append("\n")
            lines.extend(new_entry)
            content = "".join(lines) # Update content for next check
            changed = True
    
    if changed:
        with open(GROUPS_FILE, "w") as f:
            f.writelines(lines)
        return True
    return False

def main():
    print("Starting Multiverse-Inventories Sync Sidecar...")
    while True:
        try:
            groups = get_survival_groups()
            if update_groups(groups):
                print("Groups updated. Triggering Multiverse-Inventories reload...")
                subprocess.run(RELOAD_CMD)
        except Exception as e:
            print(f"Error in sync loop: {e}")
        
        time.sleep(10) # Run every 10 seconds

if __name__ == "__main__":
    main()
