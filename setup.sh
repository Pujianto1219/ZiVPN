#!/bin/bash
# ZiVPN Auto Installer (Low RAM Optimized)
# Features: IP License (AcilShop), Domain Input, Auto Swap, BBR, Tuning

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
        clear
        echo -e "${GREEN}=============================================${NC}"
        echo -e "${GREEN}          LICENSE VERIFIED - ACILSHOP        ${NC}"
        echo -e "${GREEN}=============================================${NC}"
        echo -e "${CYAN} Status   : ${GREEN}Active / Terdaftar${NC}"
        echo -e "${CYAN} IP VPS   : ${YELLOW}$MYIP${NC}"
        echo -e "${GREEN}=============================================${NC}"
        echo -e "Memulai optimasi & instalasi dalam 3 detik..."
        sleep 3
    else
        clear
        echo -e "${RED}=============================================${NC}"
        echo -e "${RED}          LICENSE INVALID - ACILSHOP         ${NC}"
        echo -e "${RED}=============================================${NC}"
        echo -e "${YELLOW} Status   : ${RED}Denied / Tidak Terdaftar${NC}"
        echo -e "${WHITE} IP Anda belum terdaftar di database kami.${NC}"
        echo -e "${RED}=============================================${NC}"
        rm -f setup.sh
        exit 1
    fi
}

# JALANKAN PENGECEKAN
check_license

# --- 1. KONFIGURASI DOMAIN ---
clear
echo ""
echo "========================================================="
echo "               KONFIGURASI DOMAIN ZIVPN                  "
echo "========================================================="
echo " Masukkan domain yang sudah dipointing ke IP VPS ini."
echo " (Contoh: vpn.acilshop.com)"
echo " * Tekan ENTER jika ingin otomatis menggunakan IP Address"
echo "========================================================="
printf " Masukkan Domain: "
read domain_input

mkdir -p /etc/zivpn > /dev/null 2>&1

if [ -z "$domain_input" ]; then
    echo " -> Tidak ada input. Menggunakan IP Address..."
    DOMAIN=$(curl -s ifconfig.me)
else
    DOMAIN="$domain_input"
fi

echo "$DOMAIN" > /etc/zivpn/domain
echo ""
echo " [OK] Domain tersimpan: $DOMAIN"
sleep 1

# --- 2. OPTIMASI SYSTEM (KHUSUS RAM KECIL) ---
clear
echo -e "${YELLOW}[System] Mengatur Timezone & Swap RAM...${NC}"

# Set Timezone WIB
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# Enable IPv4 Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

# === AUTO SWAP 1GB (Penyelamat RAM Kecil) ===
# Cek apakah swap sudah ada, jika belum buat file 1GB
if [ $(free -m | grep Swap | awk '{print $2}') -eq 0 ]; then
    echo -e "${YELLOW}[System] Membuat Swap File 1GB...${NC}"
    dd if=/dev/zero of=/swapfile bs=1024 count=1048576 > /dev/null 2>&1
    chmod 600 /swapfile
    mkswap /swapfile > /dev/null 2>&1
    swapon /swapfile > /dev/null 2>&1
    echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
else
    echo -e "${GREEN}[System] Swap File sudah ada, skip pembuatan.${NC}"
fi

# === TUNING KERNEL & NETWORK (BBR) ===
echo -e "${YELLOW}[System] Optimasi Network & Kernel...${NC}"
cat > /etc/sysctl.conf << EOF
# Tuning ZiVPN Low RAM
net.ipv4.ip_forward=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
vm.swappiness=10
vm.vfs_cache_pressure=50
net.core.rmem_max=16777216
net.core.wmem_max=16777216
fs.file-max=65535
EOF
sysctl -p > /dev/null 2>&1

# Update Limits (Agar tidak error 'Too many open files')
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

# --- 3. INSTALASI DEPENDENCIES ---
echo -e "${YELLOW}[Install] Installing Packages...${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install -y jq curl wget git zip unzip openssl python3 python3-pip cron socat > /dev/null 2>&1

systemctl stop zivpn.service > /dev/null 2>&1

# --- 4. DOWNLOAD BINARY ---
echo -e "${YELLOW}[Install] Downloading Core Service...${NC}"
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

# --- 5. CONFIG JSON ---
echo -e "${YELLOW}[Install] Creating Config...${NC}"
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

# --- 6. GENERATE SSL ---
echo -e "${YELLOW}[Install] Generating SSL...${NC}"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=ID/ST=JKT/L=JKT/O=ZiVPN/OU=VPN/CN=$DOMAIN" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" > /dev/null 2>&1

# --- 7. SERVICE SYSTEMD ---
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
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# --- 8. DOWNLOAD MENU ---
echo -e "${YELLOW}[Install] Downloading Menu...${NC}"
wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/menu.sh -O /usr/bin/menu
chmod +x /usr/bin/menu

# --- 9. START SERVICE ---
systemctl enable zivpn.service > /dev/null 2>&1
systemctl start zivpn.service > /dev/null 2>&1

# Firewall & Cleanup
IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp > /dev/null 2>&1
ufw allow 5667/udp > /dev/null 2>&1

# Auto Reboot jam 5 pagi (Opsional - menjaga kesegaran RAM)
echo "0 5 * * * root reboot" > /etc/cron.d/auto_reboot

rm -f setup.sh > /dev/null 2>&1

clear
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}      INSTALASI SELESAI               ${NC}"
echo -e "${GREEN}======================================${NC}"
echo -e "Domain : ${YELLOW}$DOMAIN${NC}"
echo -e "Status : ${GREEN}VERIFIED (ACILSHOP PREMIUM)${NC}"
echo -e "Swap   : ${GREEN}ON (1GB)${NC}"
echo -e "BBR    : ${GREEN}ON${NC}"
echo -e "Ketik ${YELLOW}menu${NC} untuk mengelola user."
