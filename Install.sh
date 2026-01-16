#!/bin/bash
set -e

GREEN="\033[1;32m"; YELLOW="\033[1;33m"; CYAN="\033[1;36m"; RED="\033[1;31m"; GRAY="\033[1;30m"; RESET="\033[0m"; BOLD="\033[1m"
print_task(){ echo -ne "${GRAY}•${RESET} $1..."; }
print_done(){ echo -e "\r${GREEN}✓${RESET} $1        "; }
print_fail(){ echo -e "\r${RED}✗${RESET} $1"; exit 1; }

# === EDIT INI ===
GITHUB_USER="Pujianto1219"
GITHUB_REPO="ZiVPN"
BRANCH="main"
# ===============

RAW_BASE="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${BRANCH}"

run_silent() {
  local msg="$1"; local cmd="$2"
  print_task "$msg"
  bash -c "$cmd" &>/tmp/zivpn_install.log
  if [ $? -eq 0 ]; then print_done "$msg"; else print_fail "$msg (cek /tmp/zivpn_install.log)"; fi
}

clear
echo -e "${BOLD}ZiVPN UDP Installer${RESET}"
echo -e "${GRAY}${GITHUB_USER} Edition${RESET}\n"

if [[ "$(uname -s)" != "Linux" ]] || [[ "$(uname -m)" != "x86_64" ]]; then
  print_fail "System not supported (Linux AMD64 only)"
fi

if [ -f /usr/local/bin/zivpn ]; then
  echo -e "${YELLOW}! ZiVPN detected. Reinstalling...${RESET}"
  systemctl stop zivpn.service 2>/dev/null || true
  systemctl stop zivpn-api.service 2>/dev/null || true
  systemctl stop zivpn-bot.service 2>/dev/null || true
fi

run_silent "Updating system" "apt-get update -y"
run_silent "Setting Timezone" "timedatectl set-timezone Asia/Jakarta"

if ! command -v go &>/dev/null; then
  run_silent "Installing dependencies" "apt-get install -y golang git net-tools curl openssl wget ufw"
else
  print_done "Dependencies ready"
fi

echo -e "\n${BOLD}Domain Configuration${RESET}"
while true; do
  read -p "Enter Domain: " domain
  [[ -n "$domain" ]] && break
done

echo -e "\n${BOLD}API Key Configuration${RESET}"
generated_key=$(openssl rand -hex 16)
echo -e "Generated Key: ${CYAN}${generated_key}${RESET}"
read -p "Enter API Key (Press Enter to use generated): " input_key
api_key="${input_key:-$generated_key}"
echo -e "Using Key: ${GREEN}${api_key}${RESET}"

# Core binary: AutoFTbot ambil dari release udp-zivpn 1.4.9 3
CORE_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"

systemctl stop zivpn.service 2>/dev/null || true
run_silent "Downloading Core" "wget -q \"$CORE_URL\" -O /usr/local/bin/zivpn && chmod +x /usr/local/bin/zivpn"

mkdir -p /etc/zivpn
echo "$domain" > /etc/zivpn/domain
echo "$api_key" > /etc/zivpn/apikey

run_silent "Configuring" "wget -q \"${RAW_BASE}/config.json\" -O /etc/zivpn/config.json"

run_silent "Generating SSL" "openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj \"/C=ID/ST=Indonesia/L=Jakarta/O=ZiVPN/OU=IT/CN=${domain}\" -keyout /etc/zivpn/zivpn.key -out /etc/zivpn/zivpn.crt"

print_task "Finding available API Port"
API_PORT=8080
while netstat -tuln | grep -q \":$API_PORT \"; do ((API_PORT++)); done
echo "$API_PORT" > /etc/zivpn/api_port
print_done "API Port selected: ${CYAN}${API_PORT}${RESET}"

# sysctl hardening minimal (optional)
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1 || true

# Service: zivpn
cat >/etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZiVPN UDP VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
LimitNOFILE=65535
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# Build API + Bot
mkdir -p /etc/zivpn/api
run_silent "Downloading API source" "wget -q \"${RAW_BASE}/zivpn-api.go\" -O /etc/zivpn/api/zivpn-api.go && wget -q \"${RAW_BASE}/go.mod\" -O /etc/zivpn/api/go.mod || true"

# Pastikan module deps untuk bot
cd /etc/zivpn/api
run_silent "Initializing go module (if needed)" "test -f go.mod || go mod init zivpn-api"
run_silent "Go mod tidy" "go mod tidy"

if go build -o zivpn-api zivpn-api.go &>/dev/null; then
  print_done "Compiling API"
else
  print_fail "Compiling API"
fi

cat >/etc/systemd/system/zivpn-api.service <<EOF
[Unit]
Description=ZiVPN Golang API Service
After=network.target zivpn.service

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn/api
Environment=ZIVPN_API_PORT=${API_PORT}
ExecStart=/etc/zivpn/api/zivpn-api
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo -e "\n${BOLD}Telegram Bot Configuration${RESET}"
echo -e "${GRAY}(Leave empty to skip)${RESET}"
read -p "Bot Token: " bot_token
read -p "Admin ID : " admin_id

if [[ -n "$bot_token" ]] && [[ -n "$admin_id" ]]; then
  read -p "Bot Mode (public/private) [default: private]: " bot_mode
  bot_mode=${bot_mode:-private}

  # Simpan config bot (sesuai pola AutoFTbot: /etc/zivpn/bot-config.json) 4
  echo "{\"bot_token\":\"$bot_token\",\"admin_id\":$admin_id,\"mode\":\"$bot_mode\",\"domain\":\"$domain\",\"api_port\":$API_PORT}" > /etc/zivpn/bot-config.json

  run_silent "Downloading Bot source" "wget -q \"${RAW_BASE}/zivpn-bot.go\" -O /etc/zivpn/api/zivpn-bot.go"
  run_silent "Downloading Bot deps" "go get github.com/go-telegram-bot-api/telegram-bot-api/v5"
  run_silent "Go mod tidy (bot)" "go mod tidy"

  if go build -o zivpn-bot zivpn-bot.go &>/dev/null; then
    print_done "Compiling Bot"
  else
    print_fail "Compiling Bot"
  fi

  cat >/etc/systemd/system/zivpn-bot.service <<EOF
[Unit]
Description=ZiVPN Telegram Bot
After=network.target zivpn-api.service

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn/api
ExecStart=/etc/zivpn/api/zivpn-bot
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable zivpn-bot.service >/dev/null 2>&1 || true
else
  print_done "Skipping Bot Setup"
fi

run_silent "Starting Services" "systemctl daemon-reload && systemctl enable zivpn.service && systemctl restart zivpn.service && systemctl enable zivpn-api.service && systemctl restart zivpn-api.service"

if systemctl list-unit-files | grep -q "^zivpn-bot.service"; then
  systemctl restart zivpn-bot.service >/dev/null 2>&1 || true
fi

# Cron auto-expire (meniru AutoFTbot yang call endpoint /api/cron/expire) 5
cron_cmd="0 0 * * * /usr/bin/curl -s -X POST -H \"X-API-Key: \$(cat /etc/zivpn/apikey)\" http://127.0.0.1:${API_PORT}/api/cron/expire >> /var/log/zivpn-cron.log 2>&1"
(crontab -l 2>/dev/null | grep -v "/api/cron/expire"; echo "$cron_cmd") | crontab -

echo -e "\n${BOLD}Installation Complete${RESET}"
echo -e "Domain  : ${CYAN}${domain}${RESET}"
echo -e "API Port: ${CYAN}${API_PORT}${RESET}"
echo -e "API Key : ${CYAN}${api_key}${RESET}"
