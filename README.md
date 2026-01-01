# Group Hardcore Survival Server

A production-ready Minecraft Hardcore system for Paper 1.21.1+, featuring group-based world isolation, shared health, and consensus voting.

## 🚀 One-Click Setup

To deploy this server, follow these steps:

### 1. Requirements
- **Docker & Docker Compose**
- **Memory**: At least 4GB RAM allocated to the container.
- **Plugins**:
  - `Skript` (Core logic)
  - `Multiverse-Core` (World management)
  - `Multiverse-Inventories` (State isolation)
  - `HealthSync` (Group health sharing)

### 2. Deployment
1. Copy the `compose.yaml` to your server directory.
2. Run the server:
   ```bash
   docker compose up -d
   ```
3. Once the server is running, access the console:
   ```bash
   docker exec -it mc-server-mc-1 rcon-cli
   ```
4. Run the initialization commands:
   ```bash
   mv load lobby
   sk reload hardcore
   group purge
   ```

## 🎮 How to Play

### Forming a Team
Players are "Ungrouped" by default and stay in the lobby.
- `/group create <name>`: Start a new team.
- `/group join <name>`: Join an existing team.
- `/group leave`: Return to the lobby and leave your team.

### Starting a Run
Teams must vote to start their survival adventure.
- `/ready`: Vote to generate/enter your team's private world.
- All online team members must `/ready` for the run to begin.

### Mechanics
- **Shared Health**: If one member takes damage, the entire team feels it. If one dies, everyone dies.
- **Private Worlds**: Each team plays in their own isolated world (`survival_g_<name>`).
- **Death**: Upon death, the team's run ends, the world is deleted, and everyone is sent back to the lobby to try again.

## 🛠 Admin Commands
- `/group purge`: **Factory Reset**. Wipes all teams, deletes all run worlds, and cleans the UI.
- `/group sync`: Forces a UI refresh for everyone.
- `/group removebar <id>`: Manually delete a ghost bossbar (see `/bossbar list`).
- `/group removeworld <name>`: Manually delete a world.

## 📁 Project Structure
- `data/plugins/Skript/scripts/hardcore.sk`: Main logic engine.
- `data/plugins/HealthSync/config.yml`: Health sharing configuration.
- `compose.yaml`: Docker orchestration.
