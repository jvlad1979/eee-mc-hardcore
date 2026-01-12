#!/bin/bash
# EEE Hardcore Universal Installer v5.6
# Robust Sidecar + Multi-Dimension Linkage
# Supports: Ubuntu, Arch, Fedora, OpenSUSE

set -e

echo "🏹 Starting EEE Hardcore Installation..."

# 1. Distro Detection & Dependency Installation
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ Could not detect OS. Please install Docker manually."
    exit 1
fi

install_deps() {
    case $OS in
        ubuntu|debian)
            echo "📦 Detected Ubuntu/Debian. Using apt..."
            sudo apt-get update
            sudo apt-get install -y curl docker.io docker-buildx docker-compose-v2
            ;;
        arch)
            echo "📦 Detected Arch Linux. Using pacman..."
            sudo pacman -Syu --noconfirm curl docker docker-compose
            ;;
        fedora)
            echo "📦 Detected Fedora. Using dnf..."
            sudo dnf install -y curl docker-ce docker-compose-plugin
            ;;
        opensuse*|suse)
            echo "📦 Detected OpenSUSE. Using zypper..."
            sudo zypper install -y curl docker docker-compose
            ;;
        *)
            echo "⚠️  OS $OS not explicitly supported for auto-install, but we'll try..."
            ;;
    esac
}

install_deps

# Ensure Docker is running
sudo systemctl enable --now docker || true
sudo usermod -aG docker $USER || true

# 2. Folder Structure
echo "📂 Creating directory structure..."
mkdir -p data/plugins/Skript/scripts

# 3. Generate Files
echo "📝 Generating EEE Hardcore configuration..."

# compose.yaml (v6.0)
cat << 'EOF' > compose.yaml
services:
  mc:
    image: itzg/minecraft-server:latest
    pull_policy: daily
    restart: always
    tty: true
    stdin_open: true
    ports:
      - "25565:25565"
    environment:
      EULA: "TRUE"
      TYPE: "PAPER"
      VERSION: "1.21.1"
      PLUGINS: "https://cdn.modrinth.com/data/3wmN97b8/versions/fw2C2Wui/multiverse-core-5.4.0.jar,https://cdn.modrinth.com/data/qvdtDX3s/versions/YgwE3Cbi/multiverse-inventories-5.3.0.jar,https://cdn.modrinth.com/data/xFNYAvMk/versions/oLyH9Mpt/Skript-2.13.2.jar,https://cdn.modrinth.com/data/vtawPsTo/versions/xTnZkHQL/multiverse-netherportals-5.0.3.jar"
      SPAWN_PROTECTION: "0"
      VIEW_DISTANCE: "12"
      MEMORY: "4G"
      ENABLE_RCON: "TRUE"
      RCON_PASSWORD: "hardcore_secret"
    volumes:
      - ./data:/data

  sidecar:
    image: python:3.11-slim
    restart: always
    environment:
      RCON_HOST: "mc"
      RCON_PORT: "25575"
      RCON_PASS: "hardcore_secret"
      PYTHONUNBUFFERED: "1"
    volumes:
      - ./data:/data
      - ./mvinv_sync.py:/mvinv_sync.py
    command: python3 /mvinv_sync.py
EOF

# mvinv_sync.py (v5.5 Native RCON Sidecar)
cat << 'EOF' > mvinv_sync.py
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
EOF

# hardcore.sk (v6.0 - Latest Release)
cat << 'EOF' > data/plugins/Skript/scripts/hardcore.sk
# EEE Hardcore Release v6.0
# Native Health Sync + Damage Blame + Silent UI + Canonical Portals

on load:
    set {hardcore::preparing} to false
    delete {hardcore::voting::*}
    
    # Global Lobby Setup
    execute console command "mv load lobby"
    wait 2 seconds
    execute console command "mv modify lobby set difficulty PEACEFUL"
    execute console command "mv modify lobby set pvp false"
    
    # Vanilla Survival Setup
    execute console command "mv create survival_vanilla NORMAL"
    execute console command "mv modify survival_vanilla set difficulty NORMAL"
    execute console command "mv create survival_vanilla_nether NETHER"
    execute console command "mv modify survival_vanilla_nether set difficulty NORMAL"
    execute console command "mv create survival_vanilla_the_end THE_END"
    execute console command "mv modify survival_vanilla_the_end set difficulty NORMAL"

    # Baseline Bossbar (Console only)
    execute console command "bossbar add hardcore_ungrouped ""&7No Group"""
    
    broadcast "&d&l[EEE Hardcore] &fStarting system v6.0..."

# --- Helper Functions ---

function getSafeID(t: text) :: text:
    set {_id} to lowercase {_t}
    replace all " " with "_" in {_id}
    return {_id}

function syncHealth(g: text):
    set {_leader_u} to {hardcore::group_members::%{_g}%::1}
    set {_leader} to ({_leader_u} parsed as player)
    
    if {_leader} is online:
        set {_h} to health of {_leader}
        set {_f} to food level of {_leader}
        
        loop {hardcore::group_members::%{_g}%::*}:
            set {_p} to (loop-value parsed as player)
            if {_p} is online:
                if {_p} is not {_leader}:
                    set health of {_p} to {_h}
                    set food level of {_p} to {_f}

function sync_stats(p: player):
    set {_u} to uuid of {_p}
    set {_g} to {hardcore::player_group::%{_u}%}
    
    if {_g} is not set: stop
        
    set {_h} to health of {_p}
    set {_f} to food level of {_p}
    
    loop {hardcore::group_members::%{_g}%::*}:
        set {_m_u} to loop-value
        set {_m} to ({_m_u} parsed as player)
        
        if {_m} is online:
            if {_m} is not {_p}:
                if {hardcore::syncing::%uuid of {_m}%} is not set:
                    set {hardcore::syncing::%uuid of {_m}%} to true
                    set health of {_m} to {_h}
                    set food level of {_m} to {_f}
                    delete {hardcore::syncing::%uuid of {_m}%}

# --- CENTRAL UI & TIMER LOOP ---

every 1 second:
    delete {_bar_members::*}
    
    loop all players:
        set {_u} to uuid of loop-player
        set {_g} to {hardcore::player_group::%{_u}%}
        
        if {_g} is set:
            set {_safe} to getSafeID({_g})
            set {_bar_id} to "hardcore_%{_safe}%"
        else:
            set {_bar_id} to "hardcore_ungrouped"
        
        if {_bar_members::%{_bar_id}%} is not set:
            set {_bar_members::%{_bar_id}%} to "%loop-player%"
        else:
            set {_bar_members::%{_bar_id}%} to "%{_bar_members::%{_bar_id}%}% %loop-player%"
        
        if {_g} is set:
            set {_s} to {hardcore::group_seconds::%{_g}%}
            set {_h} to floor({_s} / 3600)
            set {_m} to floor((mod({_s}, 3600)) / 60)
            set {_sec} to mod({_s}, 60)
            
            set {_world_id} to getSafeID({_g})
            set {_w_ov} to "survival_g_%{_world_id}%"
            set {_w_ne} to "survival_g_%{_world_id}%_nether"
            set {_w_en} to "survival_g_%{_world_id}%_the_end"
            set {_pw} to name of world of loop-player
            
            if {hardcore::preparing::%{_g}%} is true:
                send action bar "&e&lPreparing next world..." to loop-player
            else if {_pw} is {_w_ov} or {_w_ne} or {_w_en}:
                if {compass::current_dir::%{_u}%} is set:
                    send action bar "&f&l[ &e%{compass::current_dir::%{_u}%}% &f&l]   &fRun Time: &a%{_h}%h %{_m}%m %{_sec}%s" to loop-player
                else:
                    send action bar "&fRun Time: &a%{_h}%h %{_m}%m %{_sec}%s" to loop-player
            else:
                send action bar "&7Waiting in lobby..." to loop-player
        else if (name of world of loop-player) is not "survival_vanilla" or "survival_vanilla_nether" or "survival_vanilla_the_end":
            send action bar "&7Status: &6Ungrouped" to loop-player

    loop all players:
        set {_u} to uuid of loop-player
        set {_g} to {hardcore::player_group::%{_u}%}
        if {_g} is set:
            set {_safe} to getSafeID({_g})
            set {_target_tag} to "hc_%{_safe}%"
        else:
            set {_target_tag} to "hc_ungrouped"
        
        if {hardcore::cache::player_tag::%{_u}%} is not {_target_tag}:
            set {_old} to {hardcore::cache::player_tag::%{_u}%}
            if {_old} is set: execute console command "tag %loop-player% remove %{_old}%"
            execute console command "tag %loop-player% add %{_target_tag}%"
            set {hardcore::cache::player_tag::%{_u}%} to {_target_tag}
            set {_bossbar_dirty} to true
    
    if {_bossbar_dirty} is true:
        execute console command "bossbar set minecraft:hardcore_ungrouped players @a[tag=hc_ungrouped]"
        loop {hardcore::active_groups::*}:
            set {_g} to loop-value
            set {_safe} to getSafeID({_g})
            set {_bar_id} to "hardcore_%{_safe}%"
            execute console command "bossbar set minecraft:%{_bar_id}% players @a[tag=hc_%{_safe}%]"
    
    loop {hardcore::active_groups::*}:
        set {_g} to loop-value
        set {_safe} to getSafeID({_g})
        set {_bar_id} to "hardcore_%{_safe}%"
        
        set {_any_in_world} to false
        set {_w_ov} to "survival_g_%{_safe}%"
        set {_w_ne} to "survival_g_%{_safe}%_nether"
        set {_w_en} to "survival_g_%{_safe}%_the_end"
        
        loop all players:
            set {_pw} to name of world of loop-player
            if {_pw} is {_w_ov} or {_w_ne} or {_w_en}:
                if {hardcore::player_group::%uuid of loop-player%} is {_g}:
                    set {_any_in_world} to true
                    stop loop
        
        if {_any_in_world} is true:
            if {hardcore::preparing::%{_g}%} is false: add 1 to {hardcore::group_seconds::%{_g}%}
        
        set {_att} to {hardcore::group_attempts::%{_g}%} ? 0
        set {_title} to ({_att} is 0) ? "&7Group: &e%{_g}% &f| &7Staging..." : "&6&lAttempt %{_att}% &f(%{_g}%)"
            
        if {hardcore::cache::bossbar_title::%{_bar_id}%} is not {_title}:
            set {hardcore::cache::bossbar_title::%{_bar_id}%} to {_title}
            execute console command "bossbar set minecraft:%{_bar_id}% name ""%{_title}%"""

# --- Group Management ---

command /group [<text>] [<text>]:
    aliases: /hardcore, /hc
    trigger:
        if arg-1 is "create":
            set {_u} to uuid of player
            if {hardcore::player_group::%{_u}%} is set: send "&cAlready in a group!" to player
            else if arg-2 is not set: send "&cUsage: /group create <name>" to player
            else:
                set {hardcore::player_group::%{_u}%} to arg-2
                if {hardcore::active_groups::*} does not contain arg-2: add arg-2 to {hardcore::active_groups::*}
                add {_u} to {hardcore::group_members::%arg-2%::*}
                set {hardcore::group_attempts::%arg-2%} to 0
                set {hardcore::group_seconds::%arg-2%} to 0
                syncHealth(arg-2)
                set {_safe} to getSafeID(arg-2)
                execute console command "bossbar add hardcore_%{_safe}% ""&eCreating Group..."""
                execute console command "bossbar set hardcore_%{_safe}% color yellow"
                send "&aGroup &e%arg-2% &acreated!" to player
        else if arg-1 is "join":
            set {_u} to uuid of player
            if {hardcore::player_group::%{_u}%} is set: send "&cLeave your group first!" to player
            else if {hardcore::group_members::%arg-2%::*} is not set: send "&cGroup doesn't exist." to player
            else:
                set {hardcore::player_group::%{_u}%} to arg-2
                add {_u} to {hardcore::group_members::%arg-2%::*}
                syncHealth(arg-2)
                send "&aJoined %arg-2%!" to player
        else if arg-1 is "leave":
            set {_u} to uuid of player
            set {_g} to {hardcore::player_group::%{_u}%}
            if {_g} is not set: send "&cNo group." to player
            else:
                remove {_u} from {hardcore::group_members::%{_g}%::*}
                delete {hardcore::player_group::%{_u}%}
                syncHealth({_g})
                if size of {hardcore::group_members::%{_g}%::*} is 0:
                    remove {_g} from {hardcore::active_groups::*}
                    set {_safe} to getSafeID({_g})
                    execute console command "bossbar remove hardcore_%{_safe}%"
                    delete {hardcore::group_members::%{_g}%::*}
                teleport player to spawn of world "lobby"
                send "&eLeft group." to player
        else if arg-1 is "purge":
            if player is not op: send "&cAdmin command only." to player
            else:
                broadcast "&c&l[Admin] &fNUCLEAR RESET: Wiping all data and bars..."
                loop {hardcore::active_groups::*}:
                    set {_safe} to getSafeID(loop-value)
                    execute console command "bossbar remove hardcore_%{_safe}%"
                execute console command "bossbar remove hardcore_ungrouped"
                delete {hardcore::*}
                broadcast "&7- Variables and Caches wiped."
                wait 1 second
                execute console command "bossbar add hardcore_ungrouped ""&7No Group"""
                loop all players:
                    teleport loop-player to spawn of world "lobby"
                    heal loop-player
                    set food level of loop-player to 10
                send "&aSystem reset. Use /group create to start fresh." to player
        else if arg-1 is "debug_vars":
            if player is not op: stop
            broadcast "&6--- Variable Debug ---"
            broadcast "&7Active Groups: &f%{hardcore::active_groups::*}%"
            loop {hardcore::active_groups::*}:
                broadcast "&7- Group &e%loop-value%&7 members: &f%{hardcore::group_members::%loop-value%::*}%"
            send "&aCheck chat/logs for variable state." to player
        else: send "&6/group create <name>, join <name>, leave, purge, debug_vars" to player

command /ready:
    trigger:
        set {_u} to uuid of player
        set {_g} to {hardcore::player_group::%{_u}%}
        if {_g} is not set: send "&cNeed a group!" to player
        else:
            set {hardcore::votes::%{_g}%::%{_u}%} to true
            set {_online} to 0
            loop {hardcore::group_members::%{_g}%::*}:
                if (loop-value parsed as player) is online: add 1 to {_online}
            if (size of {hardcore::votes::%{_g}%::*}) >= {_online}:
                delete {hardcore::votes::%{_g}%::*}
                start_run({_g})
            else:
                set {_v} to size of {hardcore::votes::%{_g}%::*}
                loop all players:
                    if {hardcore::player_group::%uuid of loop-player%} is {_g}: send "&eReady: %{_v}%/%{_online}%" to loop-player

function start_run(g: text):
    set {hardcore::preparing::%{_g}%} to true
    set {_safe} to getSafeID({_g})
    set {_world} to "survival_g_%{_safe}%"
    loop {hardcore::group_members::%{_g}%::*}:
        set {_p} to (loop-value parsed as player)
        if {_p} is online:
            teleport {_p} to spawn of world "lobby"
            heal {_p}
            set food level of {_p} to 10
    execute console command "mv delete ""%{_world}%"""
    execute console command "mv confirm"
    execute console command "mv delete ""%{_world}%_nether"""
    execute console command "mv confirm"
    execute console command "mv delete ""%{_world}%_the_end"""
    execute console command "mv confirm"
    wait 5 seconds
    set {_seed} to random integer between 1 and 999999999
    execute console command "mv create ""%{_world}%"" NORMAL -s %{_seed}%"
    wait 2 seconds
    execute console command "mv create ""%{_world}%_nether"" NETHER -s %{_seed}%"
    wait 2 seconds
    execute console command "mv create ""%{_world}%_the_end"" THE_END -s %{_seed}%"
    wait 10 seconds
    execute console command "mv modify ""%{_world}%"" set difficulty HARD"
    execute console command "mv modify ""%{_world}%_nether"" set difficulty HARD"
    execute console command "mv modify ""%{_world}%_the_end"" set difficulty HARD"
    add 1 to {hardcore::group_attempts::%{_g}%}
    set {hardcore::group_seconds::%{_g}%} to 0
    set {hardcore::preparing::%{_g}%} to false
    wait 2 seconds
    loop {hardcore::group_members::%{_g}%::*}:
        set {_p} to (loop-value parsed as player)
        if {_p} is online: teleport {_p} to spawn of world {_world}
    broadcast "&d&l[EEE Hardcore] &fTeam &e%{_g}% &fstarted &6&lAttempt %{hardcore::group_attempts::%{_g}%}%&f!"

on death of player:
    set {_g} to {hardcore::player_group::%uuid of victim%}
    if {_g} is set:
        loop {hardcore::group_members::%{_g}%::*}:
            set {_p} to (loop-value parsed as player)
            if {_p} is online:
                if {_p} is not victim: kill {_p}
        broadcast "&c&l[EEE Hardcore] &fTeam %{_g}% &chas perished!"

on respawn:
    if {hardcore::player_group::%uuid of player%} is set:
        wait 1 tick
        teleport player to spawn of world "lobby"

on damage of player:
    if name of world of victim is "lobby":
        cancel event
        stop
    set {_u} to uuid of victim
    if {hardcore::player_group::%{_u}%} is set:
        if {hardcore::syncing::%{_u}%} is not set:
            if final damage > 0:
                set {_d} to (final damage / 2)
                broadcast "&c&l[EEE Hardcore] &f%victim% &ctook &e%{_d}% &chearts of damage!"
        if {hardcore::syncing::%{_u}%} is not set:
            set {hardcore::syncing::%{_u}%} to true
            wait 1 tick
            sync_stats(victim)
            delete {hardcore::syncing::%{_u}%}

on heal:
    set {_u} to uuid of player
    if {hardcore::player_group::%{_u}%} is set:
        if {hardcore::syncing::%{_u}%} is not set:
            set {hardcore::syncing::%{_u}%} to true
            wait 1 tick
            sync_stats(player)
            delete {hardcore::syncing::%{_u}%}

on food level change:
    set {_u} to uuid of player
    if {hardcore::player_group::%{_u}%} is set:
        if {hardcore::syncing::%{_u}%} is not set:
            set {hardcore::syncing::%{_u}%} to true
            wait 1 tick
            sync_stats(player)
            delete {hardcore::syncing::%{_u}%}
EOF

# vanilla.sk (v6.0)
cat << 'EOF' > data/plugins/Skript/scripts/vanilla.sk
# EEE Vanilla Integration v6.0
command /vanilla [<text>]:
    trigger:
        if arg-1 is "join":
            set {_u} to uuid of player
            set {_g} to {hardcore::player_group::%{_u}%}
            if {_g} is set:
                execute player command "/group leave"
                send "&7[Vanilla] Automatically left your hardcore group." to player
            execute console command "mv tp %player% survival_vanilla"
            send "&aWelcome to Vanilla Survival! (No shared health)" to player
        else if arg-1 is "leave":
            execute console command "mv tp %player% lobby"
            send "&eReturned to Lobby." to player
        else if arg-1 is "regenerate":
            if player is not op:
                send "&cAdmin command only." to player
                stop
            broadcast "&c&l[Vanilla] &fRegenerating survival world! Evacuating players..."
            loop all players:
                set {_pw} to name of world of loop-player
                if {_pw} is "survival_vanilla" or "survival_vanilla_nether" or "survival_vanilla_the_end":
                    teleport loop-player to spawn of world "lobby"
            wait 2 seconds
            execute console command "mv delete survival_vanilla"
            execute console command "mv confirm"
            execute console command "mv delete survival_vanilla_nether"
            execute console command "mv confirm"
            execute console command "mv delete survival_vanilla_the_end"
            execute console command "mv confirm"
            wait 5 seconds
            set {_seed} to random integer between 1 and 999999999
            broadcast "&7- Creating new Overworld..."
            execute console command "mv create survival_vanilla NORMAL -s %{_seed}%"
            wait 2 seconds
            broadcast "&7- Creating new Nether..."
            execute console command "mv create survival_vanilla_nether NETHER -s %{_seed}%"
            wait 2 seconds
            broadcast "&7- Creating new End..."
            execute console command "mv create survival_vanilla_the_end THE_END -s %{_seed}%"
            wait 10 seconds
            execute console command "mv modify survival_vanilla set difficulty NORMAL"
            execute console command "mv modify survival_vanilla_nether set difficulty NORMAL"
            execute console command "mv modify survival_vanilla_the_end set difficulty NORMAL"
            broadcast "&a&l[Vanilla] &fRegeneration complete! Seed: &e%{_seed}%"
        else:
            send "&6/vanilla join &7- Enter the persistent vanilla world" to player
            send "&6/vanilla leave &7- Return to the lobby" to player
            if player is op:
                send "&c/vanilla regenerate &7- WIPE and recreate world (Admin)" to player

every 3 seconds:
    loop all players:
        if name of world of loop-player is "survival_vanilla" or "survival_vanilla_nether" or "survival_vanilla_the_end":
            if {hardcore::player_group::%uuid of loop-player%} is not set:
                send action bar "&fWorld: &bVanilla Survival &7| &fPersonal Stats Only" to loop-player
EOF

# 4. Finalize
echo "🚀 Everything is ready! Starting the server..."
docker compose up -d

echo "✅ EEE Hardcore Installation Complete!"
echo "--------------------------------------------------"
echo "To finish setup, run these commands in the server console:"
echo "1. mv load lobby"
echo "2. sk reload hardcore"
echo "3. sk reload vanilla"
echo "4. group purge"
echo "--------------------------------------------------"
echo "Enjoy EEE Hardcore (v6.0)!"
