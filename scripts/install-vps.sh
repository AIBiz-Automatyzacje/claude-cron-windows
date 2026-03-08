#!/usr/bin/env bash
set -euo pipefail

# ============================================
#  CLAUDE-CRON — VPS Installer
#  One-command setup for Linux VPS
# ============================================

REPO="https://github.com/AIBiz-Automatyzacje/claude-cron.git"
INSTALL_DIR="$HOME/claude-cron"
SERVICE_NAME="claude-cron"
DEFAULT_PORT=7777

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[info]${NC} $1"; }
ok()    { echo -e "${GREEN}[ok]${NC} $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $1"; }
fail()  { echo -e "${RED}[error]${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}🕹️  CLAUDE-CRON — VPS Installer${NC}"
echo "========================================"
echo ""

# --- 1. Check Node.js ---
if ! command -v node &>/dev/null; then
  fail "Node.js nie znaleziony. Zainstaluj Node.js 18+:\n  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt install -y nodejs"
fi

NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VER" -lt 18 ]; then
  fail "Node.js $NODE_VER jest za stary. Wymagany 18+."
fi
ok "Node.js $(node -v)"

# --- 2. Check git ---
if ! command -v git &>/dev/null; then
  info "Instaluję git..."
  sudo apt-get update -qq && sudo apt-get install -y -qq git
fi
ok "git $(git --version | awk '{print $3}')"

# --- 3. Clone or update repo ---
if [ -d "$INSTALL_DIR/.git" ]; then
  info "Aktualizuję istniejącą instalację..."
  cd "$INSTALL_DIR"
  git pull --ff-only
else
  if [ -d "$INSTALL_DIR" ]; then
    warn "$INSTALL_DIR istnieje ale bez git. Tworzę backup..."
    mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%s)"
  fi
  info "Klonuję repo..."
  git clone "$REPO" "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi
ok "Repo w $INSTALL_DIR"

# --- 4. npm install ---
info "Instaluję zależności..."
cd "$INSTALL_DIR"
npm install --production 2>&1 | tail -1
ok "Zależności zainstalowane"

# --- 5. Create data dir ---
mkdir -p "$INSTALL_DIR/data"

# --- 6. Workspace dir ---
WORKSPACE="${CLAUDE_CRON_WORKSPACE:-$HOME/vault}"
if [ ! -d "$WORKSPACE" ]; then
  warn "Katalog workspace $WORKSPACE nie istnieje — tworzę..."
  mkdir -p "$WORKSPACE"
fi
info "Workspace: $WORKSPACE"

# --- 7. Check Claude CLI ---
if command -v claude &>/dev/null; then
  ok "Claude CLI znaleziony: $(which claude)"
else
  warn "Claude CLI nie znaleziony!"
  warn "Zainstaluj: npm install -g @anthropic-ai/claude-code"
  warn "Jobs nie będą się wykonywać bez Claude CLI."
fi

# --- 8. Systemd service ---
info "Tworzę systemd service..."

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
NODE_PATH=$(which node)

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Claude-Cron Skill Scheduler
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$NODE_PATH $INSTALL_DIR/server.js
Restart=on-failure
RestartSec=10

Environment=CLAUDE_CRON_PORT=$DEFAULT_PORT
Environment=CLAUDE_CRON_WORKSPACE=$WORKSPACE
Environment=PATH=$HOME/.local/bin:$HOME/.npm-global/bin:/usr/local/bin:/usr/bin:/bin

StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

# Wait a moment for startup
sleep 2

if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
  ok "Service ${SERVICE_NAME} uruchomiony"
else
  warn "Service nie wystartował. Sprawdź: sudo journalctl -u ${SERVICE_NAME} -n 20"
fi

# --- 9. Firewall ---
if command -v ufw &>/dev/null; then
  if sudo ufw status | grep -q "active"; then
    info "Otwieram port $DEFAULT_PORT w UFW..."
    sudo ufw allow "$DEFAULT_PORT"/tcp
    ok "Port $DEFAULT_PORT otwarty"
  fi
fi

# --- Done ---
echo ""
echo "========================================"
echo -e "${GREEN}🕹️  CLAUDE-CRON zainstalowany!${NC}"
echo ""
echo -e "  Dashboard:  ${CYAN}http://$(hostname -I | awk '{print $1}'):${DEFAULT_PORT}${NC}"
echo -e "  Workspace:  $WORKSPACE"
echo ""
echo "  Komendy:"
echo "    sudo systemctl status $SERVICE_NAME    # sprawdź status"
echo "    sudo journalctl -u $SERVICE_NAME -f    # logi na żywo"
echo "    sudo systemctl restart $SERVICE_NAME   # restart"
echo ""
echo "  Aby połączyć z lokalnym dashboardem:"
echo "    export CLAUDE_CRON_VPS_URL=http://TWOJ_VPS_IP:$DEFAULT_PORT"
echo ""
