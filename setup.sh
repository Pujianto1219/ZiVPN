#!/bin/bash
# Zivpn Main Trigger (One-Liner Target)

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${YELLOW}Initial Setup ZiVPN...${NC}"
mkdir -p /etc/zivpn > /dev/null 2>&1

# --- 1. INPUT DOMAIN (Ditaruh paling awal) ---
echo -e "${GREEN}=============================================${NC}"
echo -e "${YELLOW}           KONFIGURASI DOMAIN                ${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "Masukkan domain yang sudah dipointing ke IP VPS ini."
echo -e "Jika tidak punya, tekan Enter (Otomatis pakai IP)."
echo ""
read -p "Domain: " domain

# Default ke IP jika kosong
if [ -z "$domain" ]; then
    echo -e "${RED}Domain kosong, menggunakan IP Address...${NC}"
    domain=$(curl -s ifconfig.me)
fi

# Simpan domain ke file agar bisa dibaca installer.sh & menu.sh
echo "$domain" > /etc/zivpn/domain
echo -e "${GREEN}Domain disimpan: $domain${NC}"
sleep 1

# --- 2. DOWNLOAD & RUN INSTALLER ---
echo -e "${YELLOW}Downloading Core Installer...${NC}"
# Pastikan URL ini benar mengarah ke installer.sh Anda
wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/installer.sh -O /usr/local/bin/installer.sh
chmod +x /usr/local/bin/installer.sh

# Jalankan installer
bash /usr/local/bin/installer.sh

# --- 3. DOWNLOAD MENU ---
echo -e "${YELLOW}Downloading Menu...${NC}"
wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/menu.sh -O /usr/bin/menu
chmod +x /usr/bin/menu

# --- FINISH ---
rm -f setup.sh
clear
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}      INSTALASI SELESAI               ${NC}"
echo -e "${GREEN}======================================${NC}"
echo -e "Domain : ${YELLOW}$domain${NC}"
echo -e "Ketik ${YELLOW}menu${NC} untuk membuat User Pertama."
