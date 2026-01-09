#!/bin/bash

# --- Warna untuk tampilan ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Cek Root ---
if [ "${EUID}" -ne 0 ]; then
		echo -e "${RED}Script ini harus dijalankan sebagai root!${NC}"
		exit 1
fi

clear
echo -e "${BLUE}=================================================${NC}"
echo -e "${YELLOW}           INSTALLER ZiVPN AUTO SCRIPT           ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo -e ""
echo -e "Memulai proses instalasi..."
sleep 2

# 1. Update & Install Dependencies
echo -e "${GREEN}[+] Update & Upgrade System...${NC}"
apt update -y && apt upgrade -y
echo -e "${GREEN}[+] Install Dependencies (curl, wget, git, zip)...${NC}"
apt install curl wget git zip unzip -y

# 2. Buat Direktori Kerja (Opsional)
mkdir -p /etc/zivpn

# 3. Download Script Menu dari Repo Kamu
# PENTING: Ganti URL di bawah ke URL 'Raw' dari file menu.sh di GitHub kamu nanti
echo -e "${GREEN}[+] Mendownload Menu...${NC}"
wget -q -O /usr/bin/menu https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/menu.sh
chmod +x /usr/bin/menu

# 4. (Opsional) Download Config Lain dari Repo
# wget -q -O /etc/zivpn/config.json https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/config.json

echo -e "${GREEN}[+] Instalasi Selesai!${NC}"
echo -e "Ketik perintah ${YELLOW}menu${NC} untuk mengakses dashboard."
sleep 2
rm -f setup.sh
menu
