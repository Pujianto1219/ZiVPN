#!/bin/bash
# Zivpn Main Trigger

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${YELLOW}Initial Setup ZiVPN...${NC}"
mkdir -p /etc/zivpn > /dev/null 2>&1

# --- INPUT DOMAIN ---
echo -e "${GREEN}=============================================${NC}"
echo -e "${YELLOW}           KONFIGURASI DOMAIN                ${NC}"
echo -e "${GREEN}=============================================${NC}"
read -p "Masukkan Domain: " domain

# Default ke IP jika kosong
if [ -z "$domain" ]; then
    echo -e "${RED}Domain kosong, menggunakan IP...${NC}"
    domain=$(curl -s ifconfig.me)
fi

echo "$domain" > /etc/zivpn/domain
echo -e "${GREEN}Domain disimpan: $domain${NC}"
sleep 1

# --- DOWNLOAD & RUN INSTALLER ---
echo -e "${YELLOW}Downloading Core Installer...${NC}"
# Pastikan link ini mengarah ke file installer.sh di repo kamu
wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/installer.sh -O /usr/local/bin/installer.sh
chmod +x /usr/local/bin/installer.sh
bash /usr/local/bin/installer.sh

# --- DOWNLOAD MENU ---
echo -e "${YELLOW}Downloading Menu...${NC}"
# Pastikan link ini mengarah ke file menu.sh di repo kamu
wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/menu.sh -O /usr/bin/menu
chmod +x /usr/bin/menu

# --- CLEANUP & FINISH ---
rm -f setup.sh
clear
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}      INSTALASI SELESAI               ${NC}"
echo -e "${GREEN}======================================${NC}"
echo -e "Domain : ${YELLOW}$domain${NC}"
echo -e "Ketik ${YELLOW}menu${NC} untuk kelola server."
