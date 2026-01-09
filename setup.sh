#!/bin/bash
# ZiVPN Auto Installer (Ultimate Performance)
# Features: License Check, Manual Swap, CPU & Network Tuning, Domain Input

# --- 0. PERSIAPAN VARIABEL ---
export DEBIAN_FRONTEND=noninteractive
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# URL IZIN IP
PERMISSION_URL="https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/ip"

# --- 1. CEK LICENSE (ACILSHOP) ---
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
        echo -e "${CYAN} Status   : ${GREEN}Active / Premium${NC}"
        echo -e "${CYAN} IP VPS   : ${YELLOW}$MYIP${NC}"
        echo -e "${GREEN}=============================================${NC}"
        echo -e "License valid! Memulai konfigurasi..."
        sleep 2
    else
        clear
        echo -e "${RED}=============================================${NC}"
        echo -e "${RED}          LICENSE INVALID - ACILSHOP         ${NC}"
        echo -e "${RED}=============================================${NC}"
        echo -e "${YELLOW} IP VPS   : ${RED}$MYIP${NC}"
        echo -e "${WHITE} IP Anda belum terdaftar.${NC}"
        echo -e "${RED}=============================================${NC}"
        rm -f setup.sh
        exit 1
    fi
}
check_license

# --- 2. KONFIGURASI SWAP RAM (MANUAL INPUT) ---
clear
echo -e "${YELLOW}=============================================${NC}"
echo -e "${CYAN}          KONFIGURASI SWAP RAM (VIRTUAL)     ${NC}"
echo -e "${YELLOW}=============================================${NC}"
echo -e "Pilih ukuran Swap untuk mencegah VPS error/kill:"
echo -e "[1] 1 GB (Rekomendasi RAM < 1GB)"
echo -e "[2] 2 GB (Rekomendasi RAM 2GB)"
echo -e "[3] 4 GB"
echo -e "[4] 8 GB"
echo -e "[x] Skip / Jangan Buat Swap"
echo -e "---------------------------------------------"
read -p "Pilih [1-4/x]: " swap_pilih

case $swap_pilih in
    1) SWAP_SIZE=1048576; MSG="1GB" ;;
    2) SWAP_SIZE=2097152; MSG="2GB" ;;
    3) SWAP_SIZE=4194304; MSG="4GB" ;;
    4) SWAP_SIZE=8388608; MSG="8GB" ;;
    x|X) SWAP_SIZE=0; MSG="SKIP" ;;
    *) SWAP_SIZE=1048576; MSG="1GB (Default)" ;; # Default ke 1GB jika salah tekan
esac

if [ $SWAP_SIZE -gt 0 ]; then
    echo -e "${CYAN}-> Membuat Swap File $MSG... Mohon tunggu.${NC}"
    # Hapus swap lama jika ada
    swapoff -a >/dev/null 2>&1
    rm -f /swapfile >/dev/null 2>&1
    
    # Buat baru
    dd if=/dev/zero of=/swapfile bs=1024 count=$SWAP_SIZE > /dev/null 2>&1
    chmod 600 /swapfile
    mkswap /swapfile > /dev/null 2>&1
    swapon /swapfile > /dev/null 2>&1
    # Tambah ke fstab agar permanen
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
    fi
    echo -e "${GREEN}-> Swap $MSG Berhasil Dibuat!${NC}"
else
    echo -e "${YELLOW}-> Swap dilewati.${NC}"
fi
sleep 2

# --- 3. SYSTEM, CPU & BANDWIDTH OPTIMIZATION ---
clear
echo -e "${YELLOW}[System] Melakukan Optimasi CPU & Network...${NC}"

# A. Set Timezone
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# B. Install Tools Optimasi
apt-get update -y > /dev/null 2>&1
apt-get install -y cpufrequtils irqbalance > /dev/null 2>&1

# C. CPU Governor -> Performance
echo -e "${CYAN}-> Mengatur CPU Governor ke Performance...${NC}"
echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
systemctl restart cpufrequtils > /dev/null 2>&1

# D. Tuning Sysctl (Network, BBR, CPU Scheduler)
echo -e "${CYAN}-> Menerapkan Tuning Kernel & TCP Stack...${NC}"
cat > /etc/sysctl.conf << EOF
# --- ZiVPN TUNING START ---
# 1. IP Forwarding
net.ipv4.ip_forward=1

# 2. BBR & Congestion Control (Speed Boost)
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# 3. Network Buffer & Windows (Bandwidth Optimization)
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.core.netdev_max_backlog=16384
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_mtu_probing=1

# 4. Connection Limits
fs.file-max=1000000
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_tw_reuse=1

# 5. Swap Strategy (Agar RAM fisik diutamakan)
vm.swappiness=10
vm.vfs_cache_pressure=50

# 6. CPU Scheduler Tuning
kernel.sched_migration_cost_ns=5000000
kernel.sched_autogroup_enabled=0
# --- ZiVPN TUNING END ---
EOF
sysctl -p > /dev/null 2>&1

# Update Limits (File Descriptors)
echo "* soft nofile 1000000" > /etc/security/limits.conf
echo "* hard nofile 1000000" >> /etc/security/limits.conf
echo "root soft nofile 1000000" >> /etc/security/limits.conf
echo "root hard nofile 1000000" >> /etc/security/limits.conf

echo -e "${GREEN}[System] Optimasi Selesai!${NC}"
sleep 2

# --- 4. INPUT DOMAIN ---
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

# --- 5. INSTALL DEPENDENCIES & BINARY ---
clear
echo -e "${YELLOW}[Install] Menginstall Komponen Utama...${NC}"
apt-get install -y jq curl wget git zip unzip openssl python3 python3-pip cron socat > /dev/null 2>&1

# Stop service lama
systemctl stop zivpn.service > /dev/null 2>&1

# Download Binary
echo -e "${YELLOW}[Install] Mendownload Core VPN...${NC}"
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

# --- 6. SETUP CONFIG & SSL ---
echo -e "${YELLOW}[Setup] Membuat Config & SSL...${NC}"
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

# Generate SSL
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=ID/ST=JKT/L=JKT/O=ZiVPN/OU=VPN/CN=$DOMAIN" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" > /dev/null 2>&1

# --- 7. SETUP SERVICE ---
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
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

# --- 8. DOWNLOAD MENU (FILE TERPISAH) ---
echo -e "${YELLOW}[Install] Menginstall Menu...${NC}"
wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/menu.sh -O /usr/bin/menu
chmod +x /usr/bin/menu

# --- 9. FINISHING ---
echo -e "${YELLOW}[Finish] Menjalankan Service...${NC}"
systemctl enable zivpn.service > /dev/null 2>&1
systemctl start zivpn.service > /dev/null 2>&1

# Firewall Setup
IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp > /dev/null 2>&1
ufw allow 5667/udp > /dev/null 2>&1

# Auto Reboot
echo "0 5 * * * root reboot" > /etc/cron.d/auto_reboot

rm -f setup.sh > /dev/null 2>&1

clear
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}      INSTALASI SELESAI               ${NC}"
echo -e "${GREEN}======================================${NC}"
echo -e "Domain : ${YELLOW}$DOMAIN${NC}"
echo -e "Swap   : ${YELLOW}$MSG${NC}"
echo -e "BBR    : ${GREEN}Active${NC}"
echo -e "Status : ${GREEN}VERIFIED (ACILSHOP PREMIUM)${NC}"
echo -e "Ketik ${YELLOW}menu${NC} untuk mengelola user."
