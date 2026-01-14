#!/bin/bash
# ==========================================
#  ZIVPN ULTIMATE SETUP
#  Core Logic: zi.sh | Manager: Python Bot
#  Repo: Pujianto1219/ZiVPN
# ==========================================

# --- WARNA ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- CONFIG ---
REPO="https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main"
BOT_DIR="/usr/bin"
CONFIG_DIR="/etc/zivpn"
BOT_CONFIG="${CONFIG_DIR}/bot.json"
CORE_CONFIG="${CONFIG_DIR}/config.json"

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}      INSTALLER ZIVPN CORE & BOT TELEGRAM       ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 1. CEK ROOT
if [ "${EUID}" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# 2. UPDATE SYSTEM & INSTALL DEPENDENCIES
echo -e "\n${GREEN}[1/5] Updating System...${NC}"
sudo apt-get update && apt-get upgrade -y > /dev/null 2>&1
apt-get install python3 python3-pip git wget curl jq openssl net-tools -y > /dev/null 2>&1

# Stop service lama jika ada
systemctl stop zivpn.service > /dev/null 2>&1
systemctl stop zivpn-bot.service > /dev/null 2>&1

# 3. INSTALL ZIVPN CORE (Logika dari zi.sh)
echo -e "\n${GREEN}[2/5] Installing ZiVPN Core (UDP)...${NC}"

# Download Binary
echo "Downloading UDP Service..."
wget -q https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

# Setup Config Directory
mkdir -p /etc/zivpn

# Download Config Default
wget -q ${REPO}/config.json -O ${CORE_CONFIG}

# Generate Certificate (Logika zi.sh)
echo "Generating SSL Certificates..."
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=US/ST=California/L=Los Angeles/O=Zivpn/OU=IT/CN=zivpn" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" > /dev/null 2>&1

# Sysctl Tuning (Logika zi.sh)
sysctl -w net.core.rmem_max=16777216 > /dev/null 2>&1
sysctl -w net.core.wmem_max=16777216 > /dev/null 2>&1

# Create Systemd Service (Logika zi.sh)
cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# 4. KONFIGURASI PASSWORD AWAL (Logika zi.sh)
echo -e "\n${YELLOW}[USER CONFIGURATION]${NC}"
read -p "Masukkan password awal user (pisahkan koma jika banyak, tekan enter untuk default 'zi'): " input_config

if [ -n "$input_config" ]; then
    # Ubah input "pass1,pass2" menjadi format JSON array
    IFS=',' read -r -a config <<< "$input_config"
    # Format ulang string untuk sed replacement
    new_config_str="\"config\": [$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')]"
else
    # Default config
    new_config_str="\"config\": [\"zi\"]"
fi

# Inject Password ke Config.json
sed -i -E "s/\"config\": ?\[.*\]/${new_config_str}/g" ${CORE_CONFIG}

# Setup Firewall (Logika zi.sh)
echo "Setting up Firewall..."
iptables -t nat -A PREROUTING -i $(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1) -p udp --dport 6000:19999 -j DNAT --to-destination :5667
# Instal iptables-persistent agar rule tidak hilang saat reboot
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
apt-get install iptables-persistent -y > /dev/null 2>&1
netfilter-persistent save > /dev/null 2>&1

# Start Core Service
systemctl daemon-reload
systemctl enable zivpn.service > /dev/null 2>&1
systemctl start zivpn.service > /dev/null 2>&1

# 5. INSTALL BOT TELEGRAM
echo -e "\n${GREEN}[3/5] Installing Telegram Bot...${NC}"

# Install Python Libs
pip3 install pyTelegramBotAPI > /dev/null 2>&1
pip3 install telebot > /dev/null 2>&1

# Input Data Bot
echo -e "${YELLOW}[BOT CONFIGURATION]${NC}"
echo -e "Silakan masukkan data dari @BotFather:"
read -p "Input Bot Token : " bot_token
read -p "Input Admin ID  : " admin_id

if [ -z "$bot_token" ] || [ -z "$admin_id" ]; then
    echo -e "${RED}[WARNING] Data bot kosong. Bot tidak akan aktif otomatis.${NC}"
else
    # Simpan Config Bot
    cat <<EOF > $BOT_CONFIG
{
  "bot_token": "$bot_token",
  "admin_id": "$admin_id"
}
EOF
fi

# Download Script Bot
wget -q "${REPO}/bot.py" -O ${BOT_DIR}/bot.py
chmod +x ${BOT_DIR}/bot.py

# Create Systemd for Bot
cat <<EOF > /etc/systemd/system/zivpn-bot.service
[Unit]
Description=ZiVPN Telegram Bot
After=network.target

[Service]
User=root
WorkingDirectory=${BOT_DIR}
ExecStart=/usr/bin/python3 bot.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Start Bot Service
if [ -f "$BOT_CONFIG" ]; then
    systemctl enable zivpn-bot > /dev/null 2>&1
    systemctl start zivpn-bot > /dev/null 2>&1
fi

# 6. SETUP TAMBAHAN (Database Trial)
touch /etc/zivpn/user.db
touch /etc/zivpn/trial.db

# Cleanup
rm zi.* 1> /dev/null 2>&1
rm setup.sh 1> /dev/null 2>&1

# SELESAI
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}           INSTALASI SELESAI!                   ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Core Status : $(systemctl is-active zivpn.service)"
echo -e " Bot Status  : $(systemctl is-active zivpn-bot.service)"
echo -e ""
echo -e " Port VPN    : 6000-19999 (UDP)"
echo -e " Bot Token   : ${bot_token}"
echo -e ""
echo -e " Silakan cek bot Telegram Anda."
