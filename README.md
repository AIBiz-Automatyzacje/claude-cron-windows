# 🕹️ Claude-Cron

Scheduler for [Claude Code](https://claude.ai/code) — run skills and prompts on a cron schedule, via webhooks, or manually. Retro arcade dashboard included.

![Node.js](https://img.shields.io/badge/Node.js-18%2B-green) ![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue) ![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

- **Cron scheduling** — run Claude Code skills/prompts on any cron schedule
- **Webhooks** — trigger jobs from external services (Make, n8n, Zapier, etc.)
- **Dashboard** — retro arcade UI to manage jobs, view history, browse skills
- **LOCAL/VPS toggle** — manage both instances from one dashboard
- **Discord notifications** — get results delivered to a Discord channel
- **Skills browser** — scans project, user (global), and plugin skills with filters
- **Wake detection** — missed jobs run automatically after sleep/restart
- **Idle timeout + watchdog** — stuck jobs killed automatically

## Requirements

- **Node.js 18+** — [nodejs.org](https://nodejs.org)
- **Claude Code** — `npm install -g @anthropic-ai/claude-code` (must be logged in)
- **Tailscale** — private network between Mac and VPS ([tailscale.com](https://tailscale.com/download))

---

## Installation

> **Recommended path:** VPS first (24/7 job execution), then Mac (dashboard + proxy).
>
> *Only want to run locally?* Skip to [Local-only setup](#local-only-setup).

### Step 1 — VPS (Linux)

SSH into your VPS as root:

```bash
ssh root@YOUR_VPS_IP
```

Clone and run the installer:

```bash
git clone https://github.com/AIBiz-Automatyzacje/claude-cron.git /tmp/claude-cron-install
sudo bash /tmp/claude-cron-install/scripts/install-vps.sh
```

The script handles everything automatically:

1. Installs Node.js 22 (if missing)
2. Creates dedicated `claude` user (Claude CLI blocks root)
3. Installs Claude CLI globally
4. **Interactive Claude CLI login** — you'll need to complete this in the browser
5. Clones repo to `/home/claude/claude-cron`
6. Asks for configuration (workspace, port, Discord, timezone)
7. Creates systemd service (auto-restart, runs 24/7)
8. Configures firewall — port BLOCKED in UFW (Tailscale access only)
9. Optionally sets up Tailscale Funnel (for webhooks from external services)

**After installation, save your Tailscale IP** — you'll need it in Step 2:

```bash
tailscale ip -4
# example: 100.122.215.61
```

### Step 2 — Mac (local dashboard)

On your Mac:

```bash
git clone https://github.com/AIBiz-Automatyzacje/claude-cron.git ~/claude-cron
cd ~/claude-cron
bash setup.sh
```

Setup asks 4 things:

| Step | What | Example |
|------|------|---------|
| **1. VPS connection** | Tailscale IP from Step 1 | `100.122.215.61` |
| **2. Workspace** | Folder where Claude CLI runs (drag & drop from Finder works) | `~/Documents/my-vault` |
| **3. Autostart** | Start server with Claude Code? | `Y` |
| **4. Discord** | Webhook URL for notifications | empty = skip |

After setup:

```bash
source ~/.zshrc
```

### Step 3 — Verify

Open http://localhost:7777 — you should see the dashboard with a **LOCAL/VPS toggle** in the header.

- **LOCAL** (green) — jobs run on your Mac
- **VPS** (magenta) — jobs run on VPS 24/7

Switch to VPS and check that jobs/skills load correctly.

---

## Local-only Setup

If you don't have a VPS and want to run everything on your Mac:

```bash
git clone https://github.com/AIBiz-Automatyzacje/claude-cron.git ~/claude-cron
cd ~/claude-cron
bash setup.sh
```

Leave the VPS field empty in Step 1 of setup. Everything works the same, but jobs only run while your Mac is awake.

---

## Dashboard

Three tabs:

- **JOBS** — create, edit, enable/disable, trigger jobs manually
- **HISTORY** — run log with status, duration, parsed Claude output
- **SKILLS** — browse all available skills with filters (Project / User / Plugin)

### Creating a Job

Click **+ NEW JOB**:
- Choose a skill (grouped by source: Project, User, Plugin)
- Set schedule (daily, weekdays, weekly, interval, or webhook-only)
- Optionally add a prompt/arguments
- Enable Discord notification per job
- Generate webhook URL for external triggers

---

## Webhooks

Jobs can be triggered by external services via HTTP POST:

```
POST /webhook/<token>
Content-Type: application/json

{"any": "payload data"}
```

The payload is passed to Claude as context. Generate tokens in the dashboard (edit job → WEBHOOK section).

### Webhook Setup on VPS

1. **Enable Tailscale Funnel** (public HTTPS tunnel):
   ```bash
   sudo tailscale funnel --bg 7777
   ```
   You'll get a URL like `https://srv123.tail456.ts.net`

2. **Set WEBHOOK_BASE_URL** so the dashboard shows correct links:
   ```bash
   sudo systemctl edit claude-cron
   ```
   Add:
   ```ini
   [Service]
   Environment="WEBHOOK_BASE_URL=https://srv123.tail456.ts.net"
   ```
   Then: `sudo systemctl daemon-reload && sudo systemctl restart claude-cron`

3. **Generate tokens** in dashboard — edit job → WEBHOOK → Generate

4. **Test:**
   ```bash
   curl -X POST https://your-url.ts.net/webhook/YOUR-TOKEN \
     -H "Content-Type: application/json" \
     -d '{"test": true}'
   ```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CLAUDE_CRON_WORKSPACE` | Working directory for Claude CLI | Current directory |
| `CLAUDE_CRON_PORT` | Server port | `7777` |
| `CLAUDE_CRON_VPS_URL` | VPS URL for local proxy (Mac only) | — |
| `DISCORD_WEBHOOK_URL` | Discord webhook for notifications | — |
| `WEBHOOK_BASE_URL` | Public URL for webhook links (VPS only) | — |
| `WEBHOOK_ENABLED` | Set to `0` to disable webhooks | `1` |

---

## Useful Commands

### VPS

```bash
systemctl status claude-cron                    # check status
journalctl -u claude-cron -f                    # live logs
systemctl restart claude-cron                   # restart
su - claude -c 'cd ~/claude-cron && git pull'   # update code (then restart)
tailscale ip -4                                 # show Tailscale IP
sudo tailscale funnel --bg 7777                 # enable webhook tunnel
```

### Mac

```bash
cd ~/claude-cron && node server.js              # manual start
# or just open Claude Code — autostart hook launches server
```

---

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
- **Skills** are scanned from 3 sources: project, user (global), and plugin

## Security

- **Port 7777 blocked in UFW** — access only via Tailscale (private network)
- **Dashboard** reachable only from Tailscale-connected machines
- **Webhooks** (`/webhook/*`) are the only endpoints exposed via Funnel (HTTPS)
- **Claude CLI** runs as dedicated `claude` user (not root)
- Webhook tokens are UUID v4 (122 bits of entropy)

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
│   ├── skills.js      # Skill scanner (project + user + plugin)
│   ├── discord.js     # Discord webhook notifications
│   └── platform.js    # Autostart (launchd/schtasks)
├── public/
│   ├── index.html     # Dashboard UI
│   ├── app.js         # Frontend logic
│   └── style.css      # Retro arcade styling
├── scripts/
│   ├── install-vps.sh
│   └── install-windows.ps1
└── data/
    └── claude-cron.db # SQLite (created on first run)
```

## Troubleshooting

**Service won't start:**
```bash
journalctl -u claude-cron -n 30
```

**Claude CLI not logged in:**
```bash
su - claude
claude    # complete interactive login
exit
sudo systemctl restart claude-cron
```

**Wrong timezone (jobs fire at wrong time):**
```bash
timedatectl set-timezone Europe/Warsaw
sudo systemctl restart claude-cron
```

**Port accessible from public internet:**
```bash
sudo ufw deny 7777/tcp
```

**npm permission errors:**
Install global packages as root (`npm install -g ...`). The `claude` user has read-only access.
