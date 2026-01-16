#!/bin/bash
# ==========================================
#  ZIVPN MANAGER SETUP (FIXED VERSION)
#  Repo: Pujianto1219/ZiVPN
# ==========================================

# --- VARS ---
REPO="https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main"
DIR="/etc/zivpn"
BIN="/usr/local/bin/zivpn"
BOT_SCRIPT="/usr/bin/bot.py"

# --- COLOR ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}      INSTALLER ZIVPN & BOT (REVISED)           ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 1. ROOT CHECK
if [ "${EUID}" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# 2. INSTALL DEPENDENCIES
echo -e "\n${GREEN}[+] Installing System Dependencies...${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install -y python3 python3-pip git wget curl jq openssl net-tools iptables-persistent > /dev/null 2>&1

# --- PERBAIKAN PENTING DI SINI ---
# Menghapus library 'telebot' yang sering bikin crash
echo -e "${GREEN}[+] Fixing Python Libraries...${NC}"
pip3 uninstall -y telebot > /dev/null 2>&1
pip3 uninstall -y pyTelegramBotAPI > /dev/null 2>&1
# Install hanya library yang benar
pip3 install pyTelegramBotAPI > /dev/null 2>&1
# ---------------------------------

# 3. SETUP ZIVPN CORE
echo -e "${GREEN}[+] Installing ZiVPN Core...${NC}"
mkdir -p $DIR

# Download Binary
wget -q https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-amd64 -O $BIN
chmod +x $BIN

# Generate Certificate
echo -e "    Generating SSL Certificate..."
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Zivpn/CN=zivpn" \
    -keyout "$DIR/zivpn.key" -out "$DIR/zivpn.crt" > /dev/null 2>&1

# Download Config Default
wget -q "$REPO/config.json" -O "$DIR/config.json"

# Setup Systemd ZIVPN
cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=ZiVPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$BIN server -c $DIR/config.json
Restart=always
RestartSec=3
EOF

# 4. SETUP BOT TELEGRAM
echo -e "\n${GREEN}[+] Configuring Telegram Bot...${NC}"

# Input Token Bot
echo -e "${CYAN}-----------------------------------------${NC}"
read -p "Masukkan Bot Token (dari BotFather) : " bot_token
read -p "Masukkan ID Admin (ID Telegrammu)   : " admin_id
echo -e "${CYAN}-----------------------------------------${NC}"

# Simpan Config Bot
cat <<EOF > $DIR/bot_config.json
{
    "bot_token": "$bot_token",
    "admin_id": "$admin_id"
}
EOF

# Download Script Bot
echo -e "    Downloading Bot Script..."
wget -q "$REPO/bot.py" -O $BOT_SCRIPT
chmod +x $BOT_SCRIPT

# Setup Systemd Bot (Dengan Environment Log)
cat <<EOF > /etc/systemd/system/zivpn-bot.service
[Unit]
Description=ZiVPN Telegram Bot Manager
After=network.target

[Service]
User=root
WorkingDirectory=$DIR
ExecStart=/usr/bin/python3 -u $BOT_SCRIPT
Restart=always
RestartSec=3
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

# 5. FIREWALL & START
echo -e "${GREEN}[+] Finalizing Setup...${NC}"

# Iptables Rule
iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination :5667
netfilter-persistent save > /dev/null 2>&1

# Enable & Start Services
systemctl daemon-reload
systemctl enable zivpn
systemctl restart zivpn
systemctl enable zivpn-bot
systemctl restart zivpn-bot

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}           INSTALASI SUKSES!                    ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Silakan cek bot Telegram Anda sekarang."
echo -e " Jika bot masih diam, ketik: journalctl -u zivpn-bot -f"
