#!/bin/bash
# ZiVPN Auto Installer
# Features: IP License Check (AcilShop), Domain Input, Silent Install, External Menu

# --- WARNA & VARIABLE ---
export DEBIAN_FRONTEND=noninteractive
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# URL IZIN IP (Pastikan file 'ip' ada di repo kamu)
PERMISSION_URL="https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/ip"

# --- FUNGSI CEK IP (LICENSE) ---
check_license() {
    clear
    echo -e "${YELLOW}Checking License...${NC}"
    
    MYIP=$(curl -s ifconfig.me)
    IZIN=$(curl -s "$PERMISSION_URL")

    if [[ $IZIN == *"$MYIP"* ]]; then
        # === BANNER SUKSES ===
        clear
        echo -e "${GREEN}=============================================${NC}"
        echo -e "${GREEN}          LICENSE VERIFIED - ACILSHOP        ${NC}"
        echo -e "${GREEN}=============================================${NC}"
        echo -e "${CYAN} Status   : ${GREEN}Active / Terdaftar${NC}"
        echo -e "${CYAN} IP VPS   : ${YELLOW}$MYIP${NC}"
        echo -e "${CYAN} Client   : ${WHITE}Premium User${NC}"
        echo -e "${GREEN}=============================================${NC}"
        echo -e "${GREEN}        WELCOME TO ACILSHOP AUTO SCRIPT      ${NC}"
        echo -e "${GREEN}=============================================${NC}"
        echo ""
        echo -e "Memulai proses instalasi dalam 3 detik..."
        sleep 3
    else
        # === BANNER GAGAL ===
        clear
        echo -e "${RED}=============================================${NC}"
        echo -e "${RED}          LICENSE INVALID - ACILSHOP         ${NC}"
        echo -e "${RED}=============================================${NC}"
        echo -e "${YELLOW} Status   : ${RED}Denied / Tidak Terdaftar${NC}"
        echo -e "${YELLOW} IP VPS   : ${RED}$MYIP${NC}"
        echo -e "${RED}=============================================${NC}"
        echo -e "${WHITE} IP Anda belum terdaftar di database kami.${NC}"
        echo -e "${WHITE} Silakan hubungi Admin AcilShop untuk register.${NC}"
        echo -e "${RED}=============================================${NC}"
        
        rm -f setup.sh
        exit 1
    fi
}

# JALANKAN PENGECEKAN
check_license

# --- 1. CONFIGURASI DOMAIN ---
clear
echo ""
echo "========================================================="
echo "               KONFIGURASI DOMAIN ZIVPN                  "
echo "========================================================="
echo " Masukkan domain yang sudah dipointing ke IP VPS ini."
echo " (Contoh: vpn.acilshop.com)"
echo ""
echo " * Tekan ENTER jika ingin otomatis menggunakan IP Address"
echo "========================================================="
printf " Masukkan Domain: "
read domain_input

# Buat folder konfigurasi
mkdir -p /etc/zivpn > /dev/null 2>&1

if [ -z "$domain_input" ]; then
    echo " -> Tidak ada input. Menggunakan IP Address..."
    DOMAIN=$(curl -s ifconfig.me)
else
    DOMAIN="$domain_input"
fi

# Simpan ke file domain
echo "$DOMAIN" > /etc/zivpn/domain
echo ""
echo " [OK] Domain tersimpan: $DOMAIN"
sleep 2

# --- 2. INSTALASI DEPENDENCIES ---
clear
echo -e "${YELLOW}Updating System & Installing Dependencies...${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install -y jq curl wget git zip unzip openssl python3 python3-pip > /dev/null 2>&1

systemctl stop zivpn.service > /dev/null 2>&1

# --- 3. DOWNLOAD BINARY ---
echo -e "${YELLOW}Downloading Core Service...${NC}"
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    wget -q https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
elif [[ "$ARCH" == "aarch64" ]]; then
    wget -q https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-arm64 -O /usr/local/bin/zivpn
else
    echo -e "${RED}Error: Arsitektur $ARCH tidak didukung!${NC}"
    exit 1
fi
chmod +x /usr/local/bin/zivpn

# --- 4. BUAT CONFIG JSON (KOSONG) ---
echo -e "${YELLOW}Creating Empty Config...${NC}"
cat <<EOF > /etc/zivpn/config.json
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": []
  }
}
EOF

# --- 5. GENERATE SSL ---
echo -e "${YELLOW}Generating SSL Certificate for $DOMAIN...${NC}"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=ID/ST=JKT/L=JKT/O=ZiVPN/OU=VPN/CN=$DOMAIN" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" > /dev/null 2>&1

sysctl -w net.core.rmem_max=16777216 > /dev/null 2>&1
sysctl -w net.core.wmem_max=16777216 > /dev/null 2>&1

# --- 6. BUAT SERVICE ---
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

# --- 7. DOWNLOAD MENU ---
echo -e "${YELLOW}Downloading Menu Script...${NC}"
wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/menu.sh -O /usr/bin/menu
chmod +x /usr/bin/menu

# --- 8. START SERVICE ---
systemctl enable zivpn.service > /dev/null 2>&1
systemctl start zivpn.service > /dev/null 2>&1

# Firewall
IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp > /dev/null 2>&1
ufw allow 5667/udp > /dev/null 2>&1

rm -f setup.sh > /dev/null 2>&1

clear
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}      INSTALASI SELESAI               ${NC}"
echo -e "${GREEN}======================================${NC}"
echo -e "Domain : ${YELLOW}$DOMAIN${NC}"
echo -e "Status : ${GREEN}VERIFIED (ACILSHOP PREMIUM)${NC}"
echo -e "Ketik ${YELLOW}menu${NC} untuk mengelola user."
