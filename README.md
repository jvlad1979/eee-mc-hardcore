# EEE Hardcore Survival System

A production-ready Minecraft Hardcore system for Paper 1.21.1+, featuring group-based world isolation, native shared health, and consensus voting.

## 🚀 One-Click Setup

To deploy this server, follow these steps:

### 1. Requirements
- **Docker & Docker Compose**
- **Memory**: At least 4GB RAM allocated to the container.
- **Plugins**:
  - `Skript` (Core logic engine)
  - `Multiverse-Core` (World management)
  - `Multiverse-Inventories` (State & inventory isolation)
  > [!NOTE]
  > No external health sync plugins are required. The system features a custom, high-performance native sync engine.

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
- **Native Health Sync**: Every heart, half-heart, and hunger point is shared instantly within the group.
- **Detailed Damage Blame**: Whenever someone takes damage, the whole server is notified: `[EEE Hardcore] Player took X hearts of damage!`.
- **Private Worlds**: Each team plays in their own isolated world (`survival_g_<name>`).
- **Team Death**: If one person dies, the whole team is eliminated. The survival world is deleted, and everyone is sent back to the lobby.

## 🛠 Admin & Diagnostic Commands
- `/group purge`: **Nuclear Reset**. Wipes all teams, deletes all run worlds, and cleans the UI.
- `/group healthsync`: Forces all grouped players to align their stats to their group leader.
- `/group debug_vars`: Broadcasts the internal state of all group variables for auditing.

## 📁 Project Structure
- `data/plugins/Skript/scripts/hardcore.sk`: Main EEE Hardcore engine.
- `compose.yaml`: Docker orchestration.
- `README.md`: System documentation.
