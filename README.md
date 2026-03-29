# 🕹️ Claude-Cron

Scheduler for [Claude Code](https://claude.ai/code) — run skills and prompts on a cron schedule, via webhooks, or manually. Retro arcade dashboard included.

![Node.js](https://img.shields.io/badge/Node.js-18%2B-green) ![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue) ![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

- **Cron scheduling** — run Claude Code skills/prompts on any cron schedule
- **Webhooks** — trigger jobs from external services (Make, n8n, Zapier, etc.)
- **Dashboard** — retro arcade UI to manage jobs, view history, monitor runs
- **Discord notifications** — get results delivered to a Discord channel
- **VPS support** — run 24/7 on a VPS with systemd, proxy from local dashboard
- **Wake detection** — missed jobs run automatically after sleep/restart
- **Idle timeout + watchdog** — stuck jobs killed automatically

## Requirements

- **Node.js 18+** — [nodejs.org](https://nodejs.org)
- **Claude Code** — `npm install -g @anthropic-ai/claude-code` (must be logged in)

## Quick Start (macOS)

```bash
git clone https://github.com/AIBiz-Automatyzacje/claude-cron.git
cd claude-cron
bash setup.sh
```

The setup script will:
1. Check Node.js and Claude CLI
2. Ask for your workspace directory (where Claude CLI runs)
3. Install dependencies
4. Set up environment variables
5. Optionally install autostart hook for Claude Code
6. Optionally configure VPS connection and Discord

After setup, open http://localhost:7777 or just start a Claude Code session (auto-start hook launches the server).

## Manual Start

```bash
cd claude-cron
node server.js
```

Server starts at http://localhost:7777. Claude CLI runs in the current working directory unless `CLAUDE_CRON_WORKSPACE` is set.

## VPS Setup (Linux)

Run claude-cron 24/7 on a VPS. The installer handles everything — Node.js, dedicated user, systemd, firewall, Tailscale.

### Prerequisites

- **Debian/Ubuntu VPS** (tested on Ubuntu 22.04+)
- **Root access** (the script creates a dedicated `claude` user)
- **Tailscale** — secure private network between your Mac and VPS ([install](https://tailscale.com/download/linux))

### Installation

SSH into your VPS as root and run:

```bash
git clone https://github.com/AIBiz-Automatyzacje/claude-cron.git /tmp/claude-cron-install
sudo bash /tmp/claude-cron-install/scripts/install-vps.sh
```

The script will interactively:

1. **Install Node.js 22** if missing (via NodeSource)
2. **Create dedicated `claude` user** (Claude CLI blocks root)
3. **Install Claude CLI** globally
4. **Log in to Claude CLI** — interactive browser login (you'll need to complete this)
5. **Clone the repo** to `/home/claude/claude-cron`
6. **Ask for configuration:**
   - Workspace directory (where Claude CLI runs your skills)
   - Server port (default: 7777)
   - Discord webhook URL (optional)
   - Timezone
7. **Create systemd service** — auto-restart, runs as `claude` user
8. **Configure firewall** — port BLOCKED in UFW (Tailscale access only)
9. **Set up Tailscale Funnel** (optional — for webhooks from external services)

### After Installation

The script prints a summary with your Tailscale IP. Add this to `~/.zshrc` on your **Mac**:

```bash
export CLAUDE_CRON_VPS_URL=http://<TAILSCALE_IP>:7777
```

Now your local dashboard can toggle between LOCAL and VPS modes.

### Useful Commands

```bash
systemctl status claude-cron              # check status
journalctl -u claude-cron -f              # live logs
systemctl restart claude-cron             # restart after config changes
su - claude -c 'cd ~/claude-cron && git pull'  # update code (then restart)
```

### Security Model

- **Port 7777 is NOT publicly accessible** — blocked in UFW, access only via Tailscale
- **Dashboard** is only reachable from machines on your Tailscale network
- **Webhooks** (`/webhook/*`) are the only endpoints exposed via Tailscale Funnel (HTTPS)
- **Claude CLI** runs as dedicated `claude` user (not root)
- Webhook tokens are UUID v4 (122 bits of entropy)

### Webhooks on VPS

To receive webhooks from external services (Make, n8n, Zapier):

1. **Enable Tailscale Funnel** (done during install, or manually):
   ```bash
   sudo tailscale funnel --bg 7777
   ```
   This gives you a public HTTPS URL like `https://srv123.tail456.ts.net`

2. **Set WEBHOOK_BASE_URL** so the dashboard shows correct webhook links:
   ```bash
   sudo systemctl edit claude-cron
   ```
   Add between the comment lines:
   ```ini
   [Service]
   Environment="WEBHOOK_BASE_URL=https://srv123.tail456.ts.net"
   ```
   Then: `sudo systemctl daemon-reload && sudo systemctl restart claude-cron`

3. **Generate tokens** in the dashboard — edit a job → WEBHOOK section → Generate

4. **Test:**
   ```bash
   curl -X POST https://your-url.ts.net/webhook/YOUR-TOKEN \
     -H "Content-Type: application/json" \
     -d '{"test": true}'
   ```

### Troubleshooting

**Service won't start:**
```bash
journalctl -u claude-cron -n 30    # check logs
systemctl status claude-cron       # check error
```

**Claude CLI not logged in:**
```bash
su - claude
claude    # complete interactive login
exit
sudo systemctl restart claude-cron
```

**Wrong timezone (cron jobs fire at wrong time):**
```bash
timedatectl set-timezone Europe/Warsaw   # or your timezone
sudo systemctl restart claude-cron
```

**Port accessible from public internet:**
```bash
sudo ufw deny 7777/tcp    # block public access
sudo ufw status           # verify
```

**npm permission errors:**
Install global packages as root (`npm install -g ...`). The `claude` user has read-only access, which is sufficient.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CLAUDE_CRON_WORKSPACE` | Working directory for Claude CLI | Current directory |
| `CLAUDE_CRON_PORT` | Server port | `7777` |
| `CLAUDE_CRON_VPS_URL` | VPS instance URL for local proxy | — |
| `DISCORD_WEBHOOK_URL` | Discord webhook for notifications | — |
| `WEBHOOK_BASE_URL` | Public URL for webhook endpoints (VPS) | — |
| `WEBHOOK_ENABLED` | Set to `0` to disable webhooks | `1` |

## Architecture

```
[Dashboard UI] ←→ [server.js API] ←→ [executor.js → Claude CLI]
                                   ←→ [db.js → SQLite]
     ↕ (toggle)
[Proxy /api/vps/*] ←→ [VPS instance via Tailscale]
```

- **Jobs** have a cron expression, a skill/prompt, and optional webhook token
- **Runs** are queued and executed one at a time (sequential queue)
- **Output** is parsed from Claude CLI's `--output-format stream-json`
- **Dashboard** polls the API every 3s — toggle between LOCAL and VPS instances

## Webhooks

Jobs can be triggered via HTTP POST:

```
POST /webhook/<token>
Content-Type: application/json

{"any": "payload data"}
```

The payload is passed to Claude as context. Generate webhook tokens in the dashboard (edit job → WEBHOOK section).

## Project Structure

```
claude-cron/
├── server.js          # HTTP server, API, routing
├── setup.sh           # Interactive macOS setup
├── lib/
│   ├── config.js      # Environment & defaults
│   ├── db.js          # SQLite database + migrations
│   ├── executor.js    # Claude CLI spawn, timeouts, watchdog
│   ├── scheduler.js   # Cron scheduling, queue, wake detection
│   ├── skills.js      # Skill scanner (reads SKILL.md files)
│   ├── discord.js     # Discord webhook notifications
│   └── platform.js    # Autostart (launchd/schtasks)
├── public/
│   ├── index.html     # Dashboard UI
│   ├── app.js         # Frontend logic
│   └── style.css      # Retro arcade styling
├── scripts/
│   ├── install-macos.sh
│   ├── install-vps.sh
│   ├── install-windows.ps1
│   ├── uninstall-macos.sh
│   └── uninstall-windows.ps1
└── data/
    └── claude-cron.db # SQLite database (created on first run)
```
