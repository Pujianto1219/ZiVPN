#!/bin/bash
# ==========================================
#  ZIVPN MANAGER SETUP
#  Repo: Pujianto1219/ZiVPN
#  Dev : Pujianto1219
# ==========================================

# --- CONFIG ---
REPO="https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main"
DIR="/etc/zivpn"
BIN="/usr/local/bin/zivpn"
BOT_SCRIPT="/usr/bin/bot.py"

# --- WARNA ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}      INSTALLER ZIVPN & TELEGRAM BOT MANAGER    ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 1. ROOT CHECK
if [ "${EUID}" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# 2. INSTALL DEPENDENCIES
echo -e "\n${GREEN}[+] Installing Dependencies...${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install -y python3 python3-pip git wget curl jq openssl net-tools iptables-persistent > /dev/null 2>&1

# Install Python Libs untuk Bot
pip3 install pyTelegramBotAPI telebot > /dev/null 2>&1

# 3. SETUP ZIVPN CORE
echo -e "${GREEN}[+] Installing ZiVPN Core...${NC}"
mkdir -p $DIR

# Download Binary (Menggunakan binary official/stabil)
wget -q https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O $BIN
chmod +x $BIN

# Generate Certificate
echo -e "    Generating SSL Certificate..."
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Zivpn/CN=zivpn" \
    -keyout "$DIR/zivpn.key" -out "$DIR/zivpn.crt" > /dev/null 2>&1

# Download Config Default dari Repo Kamu
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

[Install]
WantedBy=multi-user.target
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

# Download Script Bot dari Repo Kamu
echo -e "    Downloading Bot Script..."
wget -q "$REPO/bot.py" -O $BOT_SCRIPT
chmod +x $BOT_SCRIPT

# Setup Systemd Bot
cat <<EOF > /etc/systemd/system/zivpn-bot.service
[Unit]
Description=ZiVPN Telegram Bot Manager
After=network.target

[Service]
User=root
WorkingDirectory=$DIR
ExecStart=/usr/bin/python3 $BOT_SCRIPT
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# 5. FIREWALL & START
echo -e "${GREEN}[+] Finalizing Setup...${NC}"

# Iptables Rule (Redirect port range ke ZiVPN port)
iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination :5667
netfilter-persistent save > /dev/null 2>&1

# Enable & Start Services
systemctl daemon-reload
systemctl enable zivpn
systemctl start zivpn
systemctl enable zivpn-bot
systemctl start zivpn-bot

# Database File Creation
touch $DIR/users.db

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}           INSTALLATION SUCCESS!                ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Command Menu : ketik /menu di Bot Telegram"
echo -e " Port UDP     : 6000-19999"
echo -e " Bot Status   : $(systemctl is-active zivpn-bot)"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
