#!/usr/bin/env bash
set -euo pipefail

# ZiVPN UDP Module installer (improved + menu + expiry + backup)
# Based on your original zi.sh, upgraded to manage passwords list + trial/expiry + auto backup

CFG="/etc/zivpn/config.json"
ZIDIR="/etc/zivpn"
AUTHDIR="/etc/zivpn/auth"
BKDIR="/etc/zivpn/backups"
EXPDB="/etc/zivpn/auth/expiry.db"     # format: password|YYYY-MM-DD
BIN="/usr/local/bin/zivpn-udp"
SVC="/etc/systemd/system/zivpn.service"

RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[0;33m"; CYAN="\033[0;36m"; NC="\033[0m"

require_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo -e "${RED}Run as root.${NC}"; exit 1; }; }

log(){ echo -e "${CYAN}[*]${NC} $*"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }

ensure_pkgs() {
  log "Updating server + installing deps (jq, openssl, curl, ufw, iptables)"
  apt-get update -y
  apt-get upgrade -y
  apt-get install -y jq openssl curl wget ufw iptables iproute2
}

ensure_dirs() {
  mkdir -p "$ZIDIR" "$AUTHDIR" "$BKDIR"
  touch "$EXPDB"
  chmod 700 "$BKDIR" "$AUTHDIR"
  chmod 600 "$EXPDB" || true
}

backup_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local ts
  ts="$(date +"%Y%m%d-%H%M%S")"
  cp -a "$f" "${BKDIR}/$(basename "$f").${ts}.bak"
  # keep last 30 backups
  ls -1t "${BKDIR}/$(basename "$f")."*.bak 2>/dev/null | tail -n +31 | xargs -r rm -f
}

download_binary_and_config() {
  log "Stopping existing service (if any)"
  systemctl stop zivpn.service >/dev/null 2>&1 || true

  log "Downloading UDP service binary"
  wget -q https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-amd64 -O "$BIN"
  chmod +x "$BIN"

  log "Downloading base config.json"
  backup_file "$CFG"
  wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/config.json -O "$CFG"
}

generate_certs() {
  log "Generating cert files"
  backup_file "${ZIDIR}/zivpn.key"
  backup_file "${ZIDIR}/zivpn.crt"
  openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" \
    -keyout "${ZIDIR}/zivpn.key" -out "${ZIDIR}/zivpn.crt"
  chmod 600 "${ZIDIR}/zivpn.key" "${ZIDIR}/zivpn.crt" || true
}

tune_kernel() {
  log "Tuning UDP buffers"
  sysctl -w net.core.rmem_max=16777216 >/dev/null 2>&1 || true
  sysctl -w net.core.wmem_max=16777216 >/dev/null 2>&1 || true
}

write_service() {
  log "Writing systemd service"
  cat > "$SVC" <<EOF
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=${BIN} server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
}

init_passwords_in_config() {
  log "Configuring initial passwords (auth.mode=passwords + auth.config=[...])"

  read -r -p "Enter passwords separated by commas (Press enter for Default 'zi'): " input_config

  local json_array
  if [[ -n "$input_config" ]]; then
    # trim spaces around commas
    input_config="$(echo "$input_config" | tr -d ' ' )"
    IFS=',' read -r -a arr <<< "$input_config"
    # create JSON array properly with jq
    json_array="$(printf '%s\n' "${arr[@]}" | jq -R . | jq -s .)"
  else
    json_array='["zi"]'
  fi

  backup_file "$CFG"
  tmp="$(mktemp)"
  jq --argjson a "$json_array" '
    .auth.mode="passwords"
    | .auth.config=$a
  ' "$CFG" > "$tmp"
  mv "$tmp" "$CFG"
}

setup_firewall() {
  log "Applying firewall + iptables DNAT"
  # Detect default interface
  IFACE="$(ip -4 route ls | awk '/default/ {print $5; exit}')"
  [[ -n "${IFACE:-}" ]] || { warn "Could not detect default interface. Skipping iptables."; return 0; }

  # idempotent iptables: add only if not exists
  if ! iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null; then
    iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667
  fi

  ufw allow 6000:19999/udp >/dev/null 2>&1 || true
  ufw allow 5667/udp >/dev/null 2>&1 || true
  ufw --force enable >/dev/null 2>&1 || true
}

install_menu() {
  log "Installing menu (separate script)"
  # expects menu.sh beside install.sh
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  [[ -f "${script_dir}/menu.sh" ]] || { warn "menu.sh not found next to installer. Skipping menu install."; return 0; }

  install -m 0755 -o root -g root "${script_dir}/menu.sh" /usr/local/sbin/zivpn-menu

  # /usr/bin/zivpn opens menu
  cat >/usr/bin/zivpn <<'EOF'
#!/usr/bin/env bash
exec sudo /usr/local/sbin/zivpn-menu
EOF
  chmod +x /usr/bin/zivpn
  ok "Menu installed. Run: zivpn"
}

install_automation_scripts() {
  log "Installing maintenance scripts (backup + cleanup expired)"
  # backup script
  cat >/usr/local/sbin/zivpn-backup <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CFG="/etc/zivpn/config.json"
BKDIR="/etc/zivpn/backups"
mkdir -p "$BKDIR"
ts="$(date +"%Y%m%d-%H%M%S")"
[[ -f "$CFG" ]] || exit 0
cp -a "$CFG" "${BKDIR}/config.json.${ts}.bak"
# keep last 30
ls -1t "${BKDIR}/config.json."*.bak 2>/dev/null | tail -n +31 | xargs -r rm -f
EOF
  chmod +x /usr/local/sbin/zivpn-backup

  # cleanup expired script
  cat >/usr/local/sbin/zivpn-expiry-clean <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CFG="/etc/zivpn/config.json"
EXPDB="/etc/zivpn/auth/expiry.db"
BKDIR="/etc/zivpn/backups"

command -v jq >/dev/null 2>&1 || exit 0
[[ -f "$CFG" ]] || exit 0
[[ -f "$EXPDB" ]] || exit 0

mkdir -p "$BKDIR"
ts="$(date +"%Y%m%d-%H%M%S")"
cp -a "$CFG" "${BKDIR}/config.json.${ts}.bak" || true

today="$(date +%Y-%m-%d)"

# Build list of expired passwords from expiry.db where exp < today
expired="$(awk -F'|' -v t="$today" 'NF>=2 && $2!="" && $2 < t {print $1}' "$EXPDB" | sed '/^$/d' | sort -u)"
[[ -z "${expired:-}" ]] && exit 0

tmp="$(mktemp)"
jq --argfile _dummy /dev/null '
  . as $root
  | .auth.config = (
      (.auth.config // [])
      | map(select(. != null))
    )
' "$CFG" >"$tmp"
mv "$tmp" "$CFG"

# remove each expired password from auth.config
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  tmp="$(mktemp)"
  jq --arg p "$p" '.auth.config = ((.auth.config // []) | map(select(. != $p)))' "$CFG" >"$tmp"
  mv "$tmp" "$CFG"
done <<<"$expired"

# also remove expired entries from expiry.db to keep clean
grep -vFf <(echo "$expired") "$EXPDB" > "${EXPDB}.tmp" || true
mv "${EXPDB}.tmp" "$EXPDB"
EOF
  chmod +x /usr/local/sbin/zivpn-expiry-clean
}

install_systemd_timers() {
  log "Installing systemd timers"

  # backup service + timer (daily)
  cat >/etc/systemd/system/zivpn-backup.service <<'EOF'
[Unit]
Description=ZiVPN backup config.json

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/zivpn-backup
EOF

  cat >/etc/systemd/system/zivpn-backup.timer <<'EOF'
[Unit]
Description=Run ZiVPN backup daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

  # expiry cleanup service + timer (every 15 minutes)
  cat >/etc/systemd/system/zivpn-expiry-clean.service <<'EOF'
[Unit]
Description=ZiVPN remove expired passwords from config

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/zivpn-expiry-clean
EOF

  cat >/etc/systemd/system/zivpn-expiry-clean.timer <<'EOF'
[Unit]
Description=Run ZiVPN expiry cleanup every 15 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now zivpn-backup.timer >/dev/null 2>&1 || true
  systemctl enable --now zivpn-expiry-clean.timer >/dev/null 2>&1 || true

  ok "Timers enabled: backup daily, expiry cleanup every 15 minutes"
}

start_service() {
  log "Enabling + starting zivpn.service"
  systemctl daemon-reload
  systemctl enable zivpn.service >/dev/null 2>&1 || true
  systemctl restart zivpn.service
}

main() {
  require_root
  ensure_pkgs
  ensure_dirs
  download_binary_and_config
  generate_certs
  tune_kernel
  write_service
  init_passwords_in_config
  install_menu
  install_automation_scripts
  install_systemd_timers
  setup_firewall
  start_service

  ok "ZIVPN UDP Installed"
  echo -e "${GREEN}Run menu:${NC} zivpn"
  echo -e "${GREEN}Binary:${NC} ${BIN}"
  echo -e "${GREEN}Config:${NC} ${CFG}"
}

main "$@"
