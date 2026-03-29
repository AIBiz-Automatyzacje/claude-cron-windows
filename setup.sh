#!/usr/bin/env bash
set -euo pipefail

# ============================================
#  CLAUDE-CRON — macOS Setup
#  Interactive installer for local Mac
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[info]${NC} $1"; }
ok()    { echo -e "${GREEN}[ok]${NC} $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $1"; }
fail()  { echo -e "${RED}[error]${NC} $1"; exit 1; }
ask()   { echo -en "${BOLD}$1${NC}"; }

# Repo = directory where this script lives
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo -e "${CYAN}🕹️  CLAUDE-CRON — macOS Setup${NC}"
echo "========================================"
echo ""

# ============ PREFLIGHT ============

info "Checking requirements..."

# macOS check
[ "$(uname)" = "Darwin" ] || fail "This script is for macOS. Use install-vps.sh for Linux."

# Node.js
if ! command -v node &>/dev/null; then
  fail "Node.js not found. Install from https://nodejs.org (18+)"
fi
NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
[ "$NODE_VER" -ge 18 ] || fail "Node.js 18+ required (found $(node -v))"
ok "Node.js $(node -v)"

# npm
command -v npm &>/dev/null || fail "npm not found"
ok "npm $(npm -v)"

# Claude CLI
if command -v claude &>/dev/null; then
  ok "Claude CLI found"
else
  warn "Claude CLI not found!"
  warn "Install: npm install -g @anthropic-ai/claude-code"
  warn "Jobs won't run without it. Setup continues anyway."
  echo ""
fi

# ============ WORKSPACE ============

echo ""
echo -e "  Podaj ścieżkę do folderu, w którym Claude CLI ma pracować."
echo -e "  ${YELLOW}Tip: przeciągnij folder z Findera tutaj i naciśnij Enter${NC}"
echo ""
ask "Ścieżka do workspace [$HOME]: "
read -r WORKSPACE_INPUT
WORKSPACE="${WORKSPACE_INPUT:-$HOME}"

# Strip quotes and trailing spaces (drag & drop from Finder adds them)
WORKSPACE="${WORKSPACE//\'/}"
WORKSPACE="${WORKSPACE//\"/}"
WORKSPACE="${WORKSPACE%% }"
WORKSPACE="${WORKSPACE## }"

# Expand ~ to $HOME
WORKSPACE="${WORKSPACE/#\~/$HOME}"

# Resolve to absolute path
WORKSPACE="$(cd "$WORKSPACE" 2>/dev/null && pwd)" || fail "Folder nie istnieje: $WORKSPACE_INPUT"

ok "Workspace: $WORKSPACE"

# ============ NPM INSTALL ============

echo ""
info "Installing dependencies..."
cd "$REPO_DIR"
npm install --production 2>&1 | tail -3
mkdir -p "$REPO_DIR/data"
ok "Dependencies installed"

# ============ ENV VARS (.zshrc) ============

echo ""
SHELL_RC="$HOME/.zshrc"

# CLAUDE_CRON_WORKSPACE
if grep -q "CLAUDE_CRON_WORKSPACE" "$SHELL_RC" 2>/dev/null; then
  info "CLAUDE_CRON_WORKSPACE already in $SHELL_RC — skipping"
else
  echo "" >> "$SHELL_RC"
  echo "# Claude-Cron workspace" >> "$SHELL_RC"
  echo "export CLAUDE_CRON_WORKSPACE=\"$WORKSPACE\"" >> "$SHELL_RC"
  ok "Added CLAUDE_CRON_WORKSPACE to $SHELL_RC"
fi

# ============ AUTOSTART HOOK ============

echo ""
HOOKS_DIR="$HOME/.claude/hooks"
HOOK_FILE="$HOOKS_DIR/claude-cron-autostart.js"

ask "Zainstalować autostart hook? (serwer startuje z Claude Code) [Y/n]: "
read -r INSTALL_HOOK
INSTALL_HOOK="${INSTALL_HOOK:-Y}"

if [[ "$INSTALL_HOOK" =~ ^[Yy]$ ]]; then
  mkdir -p "$HOOKS_DIR"

  cat > "$HOOK_FILE" <<HOOKEOF
const http = require('http');
const { spawn } = require('child_process');

const CRON_DIR = '$REPO_DIR';

const req = http.get('http://localhost:7777/api/status', { timeout: 1000 }, () => {
  process.exit(0);
});

req.on('error', () => {
  const child = spawn('node', ['server.js'], {
    cwd: CRON_DIR,
    detached: true,
    stdio: 'ignore',
  });
  child.unref();

  // Caffeinate — keep Mac awake while claude-cron is alive
  if (process.platform === 'darwin') {
    spawn('caffeinate', ['-w', String(child.pid)], {
      detached: true,
      stdio: 'ignore',
    }).unref();
  }

  console.log('🕹️ Claude-Cron started in background (localhost:7777)');
  process.exit(0);
});

req.on('timeout', () => {
  req.destroy();
});
HOOKEOF

  ok "Hook installed: $HOOK_FILE"

  # Check if hook is registered in settings.json
  SETTINGS_FILE="$HOME/.claude/settings.json"
  if [ -f "$SETTINGS_FILE" ]; then
    if grep -q "claude-cron-autostart" "$SETTINGS_FILE"; then
      ok "Hook already registered in settings.json"
    else
      warn "Hook file created but NOT registered in Claude Code settings."
      warn "Add this to $SETTINGS_FILE under hooks.UserPromptSubmit:"
      echo ""
      echo "  {\"type\": \"command\", \"command\": \"node $HOOK_FILE\"}"
      echo ""
    fi
  else
    warn "Claude Code settings not found. Register the hook manually."
  fi
else
  info "Skipping autostart hook"
fi

# ============ OPTIONAL: VPS CONNECTION ============

echo ""
echo -e "  ${YELLOW}Opcjonalne:${NC} Jeśli masz osobną instancję claude-cron na VPS,"
echo -e "  możesz podłączyć ją do tego dashboardu (toggle LOCAL/VPS)."
echo -e "  Jeśli nie wiesz o co chodzi — wybierz N."
echo ""
ask "Podłączyć zdalny VPS do dashboardu? [y/N]: "
read -r HAS_VPS
HAS_VPS="${HAS_VPS:-N}"

if [[ "$HAS_VPS" =~ ^[Yy]$ ]]; then
  ask "Tailscale IP lub adres VPS (np. 100.x.x.x): "
  read -r VPS_HOST
  VPS_PORT=7777
  ask "VPS port [$VPS_PORT]: "
  read -r VPS_PORT_INPUT
  VPS_PORT="${VPS_PORT_INPUT:-$VPS_PORT}"

  VPS_URL="http://${VPS_HOST}:${VPS_PORT}"

  if grep -q "CLAUDE_CRON_VPS_URL" "$SHELL_RC" 2>/dev/null; then
    info "CLAUDE_CRON_VPS_URL already in $SHELL_RC — skipping"
  else
    echo "" >> "$SHELL_RC"
    echo "# Claude-Cron VPS connection" >> "$SHELL_RC"
    echo "export CLAUDE_CRON_VPS_URL=\"$VPS_URL\"" >> "$SHELL_RC"
    ok "Added CLAUDE_CRON_VPS_URL=$VPS_URL to $SHELL_RC"
  fi
fi

# ============ OPTIONAL: DISCORD ============

echo ""
ask "Discord webhook URL do powiadomień? (puste = pomiń): "
read -r DISCORD_URL

if [ -n "$DISCORD_URL" ]; then
  if grep -q "DISCORD_WEBHOOK_URL" "$SHELL_RC" 2>/dev/null; then
    info "DISCORD_WEBHOOK_URL already in $SHELL_RC — skipping"
  else
    echo "" >> "$SHELL_RC"
    echo "# Claude-Cron Discord notifications" >> "$SHELL_RC"
    echo "export DISCORD_WEBHOOK_URL=\"$DISCORD_URL\"" >> "$SHELL_RC"
    ok "Added DISCORD_WEBHOOK_URL to $SHELL_RC"
  fi
fi

# ============ DONE ============

echo ""
echo "========================================"
echo -e "${GREEN}🕹️  CLAUDE-CRON setup complete!${NC}"
echo ""
echo -e "  Repo:       ${CYAN}$REPO_DIR${NC}"
echo -e "  Workspace:  ${CYAN}$WORKSPACE${NC}"
echo -e "  Dashboard:  ${CYAN}http://localhost:7777${NC}"
echo ""
echo "  Start manually:"
echo "    cd $REPO_DIR && node server.js"
echo ""
if [[ "${INSTALL_HOOK:-N}" =~ ^[Yy]$ ]]; then
  echo "  Or just open Claude Code — server starts automatically."
  echo ""
fi
echo "  Run 'source ~/.zshrc' to load env vars in current terminal."
echo ""
