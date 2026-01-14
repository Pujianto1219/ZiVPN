#!/bin/bash
# ==========================================
#  ZIVPN BOT INSTALLER (BRANCH 1.0)
#  Repo: Pujianto1219/ZiVPN/tree/1.0
# ==========================================

# --- WARNA ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- CONFIG BRANCH 1.0 ---
# Pastikan REPO mengarah ke branch "1.0"
REPO="https://raw.githubusercontent.com/Pujianto1219/ZiVPN/1.0"
BOT_DIR="/usr/bin"
CONFIG_DIR="/etc/zivpn"
BOT_CONFIG="${CONFIG_DIR}/bot.json"

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}       INSTALLER BOT TELEGRAM (ZIVPN v1.0)      ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 1. CEK ROOT
if [ "${EUID}" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# 2. INSTALL PYTHON & DEPENDENCIES
echo -e "\n${GREEN}[1/4] Installing Python Environment...${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install python3 python3-pip git wget curl -y > /dev/null 2>&1

# Install Modul Telegram
pip3 install pyTelegramBotAPI > /dev/null 2>&1
pip3 install telebot > /dev/null 2>&1

# 3. KONFIGURASI BOT
echo -e "\n${GREEN}[2/4] Setup Konfigurasi Bot...${NC}"
mkdir -p $CONFIG_DIR

# Cek jika config sudah ada, tanya mau timpa atau tidak
if [ -f "$BOT_CONFIG" ]; then
    echo -e "${YELLOW}Konfigurasi bot ditemukan.${NC}"
    read -p "Apakah ingin memasukkan Token baru? (y/n): " ganti_token
    if [[ "$ganti_token" == "y" ]]; then
        ask_token=true
    else
        ask_token=false
    fi
else
    ask_token=true
fi

if [ "$ask_token" = true ]; then
    echo -e "Silakan masukkan data dari @BotFather:"
    read -p "Input Bot Token : " bot_token
    read -p "Input Admin ID  : " admin_id

    if [ -z "$bot_token" ] || [ -z "$admin_id" ]; then
        echo -e "${RED}[ERROR] Data tidak boleh kosong!${NC}"
        exit 1
    fi

    # Simpan ke JSON
    cat <<EOF > $BOT_CONFIG
{
  "bot_token": "$bot_token",
  "admin_id": "$admin_id"
}
EOF
fi

# 4. DOWNLOAD SCRIPT BOT (DARI BRANCH 1.0)
echo -e "\n${GREEN}[3/4] Downloading Bot Script (Branch 1.0)...${NC}"
wget -q "${REPO}/bot.py" -O ${BOT_DIR}/bot.py
chmod +x ${BOT_DIR}/bot.py

# Validasi Download
if [ ! -s "${BOT_DIR}/bot.py" ]; then
    echo -e "${RED}[ERROR] Gagal download bot.py!${NC}"
    echo -e "Pastikan file 'bot.py' sudah ada di branch '1.0' repo GitHub Anda."
    exit 1
fi

# 5. MEMBUAT SERVICE SYSTEMD
echo -e "\n${GREEN}[4/4] Activating Service...${NC}"
cat <<EOF > /etc/systemd/system/zivpn-bot.service
[Unit]
Description=ZiVPN Telegram Bot Service
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

# Reload & Start Service
systemctl daemon-reload
systemctl stop zivpn-bot > /dev/null 2>&1
systemctl enable zivpn-bot > /dev/null 2>&1
systemctl start zivpn-bot > /dev/null 2>&1

# Selesai
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}           BOT BERHASIL DIINSTALL!              ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Branch     : 1.0"
echo -e " Status Bot : $(systemctl is-active zivpn-bot)"
echo -e ""
echo -e " Silakan cek bot Telegram Anda sekarang."
