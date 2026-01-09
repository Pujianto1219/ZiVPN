#!/bin/bash

# ==========================================================
#  SCRIPT INSTALLER: ZIVPN + DOMAIN VALIDATION + LICENSE
# ==========================================================

# --- Warna untuk Tampilan ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- 1. PRE-CHECK & DEPENDENCIES ---
# Install dnsutils & curl di awal agar tidak error saat cek IP/Domain
echo -e "${CYAN}[SYSTEM] Installing initial dependencies...${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install dnsutils curl -y > /dev/null 2>&1

# Dapatkan IP VPS
MYIP=$(curl -sS ipv4.icanhazip.com)

# --- 2. FUNGSI CEK LICENSE (IP & DURASI) ---
function check_license() {
    # Ganti URL ini dengan URL raw text file izin Anda
    IZIN_URL="https://raw.githubusercontent.com/Pujianto1219/repo/main/ip.txt"
    
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           MEMERIKSA LISENSI SERVER...          ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    DATA_IZIN=$(curl -sS "$IZIN_URL" | grep "$MYIP")
    
    if [[ -n "$DATA_IZIN" ]]; then
        IFS='|' read -r REGISTERED_IP EXPIRED_DATE <<< "$DATA_IZIN"
        echo -e "IP Server  : ${YELLOW}$REGISTERED_IP${NC}"
        echo -e "Masa Aktif : ${GREEN}$EXPIRED_DATE${NC}"
        echo -e "Status     : ${GREEN}Premium Lifetime/Active${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        sleep 2
    else
        echo -e "${RED}[AKSES DITOLAK]${NC}"
        echo -e "IP $MYIP tidak terdaftar di database kami."
        echo -e "Silakan hubungi Admin AcilShop."
        exit 1
    fi
}

# --- 3. FUNGSI CEK DOMAIN (LOOPING VALIDATION) ---
function check_domain_pointing() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           KONFIGURASI DOMAIN SERVER            ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "IP VPS Anda : ${GREEN}$MYIP${NC}"
    echo -e "Pastikan domain sudah dipointing (A Record) ke IP ini."
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    while true; do
        echo -n -e "Input Domain: ${GREEN}"
        read input_domain
        echo -e "${NC}"
        
        # Bersihkan spasi
        DOMAIN=$(echo $input_domain | xargs)

        if [[ -z "$DOMAIN" ]]; then
            echo -e "${RED}[ERROR] Domain tidak boleh kosong!${NC}"
            continue
        fi

        # Cek IP Domain
        echo -e "${YELLOW}[PROCESS] Memeriksa DNS propagation...${NC}"
        domain_ip=$(dig +short "$DOMAIN" | head -n1)
        sleep 1

        if [[ "$domain_ip" == "$MYIP" ]]; then
            echo -e "${GREEN}[SUKSES] Domain $DOMAIN valid mengarah ke $MYIP.${NC}"
            
            # Simpan data
            mkdir -p /etc/zivpn
            mkdir -p /root
            echo "$DOMAIN" > /root/domain
            echo "$DOMAIN" > /etc/zivpn/domain # Cadangan
            break
            
        elif [[ -z "$domain_ip" ]]; then
             echo -e "${RED}[ERROR] Domain tidak ditemukan / DNS belum propagasi.${NC}"
             echo -e "Silakan cek penulisan atau tunggu beberapa saat."
             echo -e "Coba lagi...\n"
        else
            echo -e "${RED}[ERROR] Domain $DOMAIN mengarah ke $domain_ip${NC}"
            echo -e "${RED}        Seharusnya ke $MYIP${NC}"
            echo -e "Silakan perbaiki DNS Record di Cloudflare."
            echo -e "Sistem menunggu input ulang...\n"
        fi
    done
}

# --- 4. FUNGSI SWAP RAM ---
function install_swap() {
    clear
    echo -e "${YELLOW}=============================================${NC}"
    echo -e "${CYAN}          KONFIGURASI SWAP RAM (VIRTUAL)     ${NC}"
    echo -e "${YELLOW}=============================================${NC}"
    echo -e "[1] 1 GB (Rekomendasi RAM < 1GB)"
    echo -e "[2] 2 GB (Rekomendasi RAM 2GB)"
    echo -e "[3] 4 GB"
    echo -e "[x] Skip / Jangan Buat Swap"
    echo -e "---------------------------------------------"
    read -p "Pilih [1-3/x]: " swap_pilih

    case $swap_pilih in
        1) SWAP_SIZE=1048576; SWAP_MSG="1GB" ;;
        2) SWAP_SIZE=2097152; SWAP_MSG="2GB" ;;
        3) SWAP_SIZE=4194304; SWAP_MSG="4GB" ;;
        x|X) SWAP_SIZE=0; SWAP_MSG="SKIP" ;;
        *) SWAP_SIZE=1048576; SWAP_MSG="1GB (Default)" ;;
    esac

    if [ $SWAP_SIZE -gt 0 ]; then
        echo -e "${CYAN}-> Membuat Swap File $SWAP_MSG...${NC}"
        swapoff -a >/dev/null 2>&1
        rm -f /swapfile >/dev/null 2>&1
        dd if=/dev/zero of=/swapfile bs=1024 count=$SWAP_SIZE > /dev/null 2>&1
        chmod 600 /swapfile
        mkswap /swapfile > /dev/null 2>&1
        swapon /swapfile > /dev/null 2>&1
        if ! grep -q "/swapfile" /etc/fstab; then
            echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
        fi
        echo -e "${GREEN}-> Swap Berhasil!${NC}"
    else
        echo -e "${YELLOW}-> Swap dilewati.${NC}"
    fi
    sleep 1
}

# --- 5. FUNGSI OPTIMASI SYSTEM ---
function optimize_system() {
    clear
    echo -e "${YELLOW}[System] Melakukan Optimasi CPU & Network...${NC}"

    ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
    apt-get install -y cpufrequtils irqbalance > /dev/null 2>&1

    echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
    systemctl restart cpufrequtils > /dev/null 2>&1

    # Tuning Kernel
    cat > /etc/sysctl.conf << EOF
net.ipv4.ip_forward=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_mtu_probing=1
fs.file-max=1000000
EOF
    sysctl -p > /dev/null 2>&1
    
    # Limits
    echo "* soft nofile 1000000" > /etc/security/limits.conf
    echo "* hard nofile 1000000" >> /etc/security/limits.conf

    echo -e "${GREEN}[System] Optimasi Selesai!${NC}"
    sleep 2
}

# ==========================================================
#  EKSEKUSI UTAMA (MAIN EXECUTION)
# ==========================================================

# 1. Cek License
check_license

# 2. Setup Domain
check_domain_pointing

# 3. Setup Swap
install_swap

# 4. Optimasi System
optimize_system

# --- 6. INSTALL CORE VPN & DEPENDENCIES ---
clear
echo -e "${YELLOW}[Install] Menginstall Komponen Utama...${NC}"
apt-get install -y jq curl wget git zip unzip openssl python3 python3-pip cron socat netfilter-persistent iptables-persistent > /dev/null 2>&1

# Stop service jika ada
systemctl stop zivpn.service > /dev/null 2>&1

# Download Binary
echo -e "${YELLOW}[Install] Mendownload Core VPN...${NC}"
mkdir -p /usr/local/bin
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

# --- 7. CONFIGURATION & SSL ---
echo -e "${YELLOW}[Setup] Membuat Config & SSL...${NC}"
mkdir -p /etc/zivpn

# Config JSON
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

# Generate SSL (Menggunakan variable $DOMAIN yang didapat dari fungsi check_domain_pointing)
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=ID/ST=JKT/L=JKT/O=ZiVPN/OU=VPN/CN=$DOMAIN" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" > /dev/null 2>&1

# Service Systemd
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

# --- 8. DOWNLOAD MENU ---
echo -e "${YELLOW}[Install] Menginstall Menu...${NC}"
wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/menu.sh -O /usr/bin/menu
chmod +x /usr/bin/menu

# --- 9. FINISHING SERVICE ---
echo -e "${YELLOW}[Finish] Menjalankan Service...${NC}"
systemctl daemon-reload
systemctl enable zivpn.service > /dev/null 2>&1
systemctl start zivpn.service > /dev/null 2>&1

# Firewall Setup
IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
# Simpan aturan iptables agar tidak hilang saat reboot
netfilter-persistent save > /dev/null 2>&1
netfilter-persistent reload > /dev/null 2>&1

# Auto Reboot
echo "0 5 * * * root reboot" > /etc/cron.d/auto_reboot

# --- 10. NOTIFIKASI TELEGRAM ---
BOT_TOKEN="8194078306:AAGcRbkEStZeHFd2Fj6e8p8c_YPUrXHl1dw"
ADMIN_ID="6355497501"

ISP=$(curl -s ipinfo.io/org)
CITY=$(curl -s ipinfo.io/city)
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Format Pesan HTML (Menggunakan SWAP_MSG agar tidak bentrok)
TG_MSG="
<code>---------------------------</code>
<b>✅ INSTALLATION SUCCESS</b>
<code>---------------------------</code>
<b>Domain   :</b> <code>$DOMAIN</code>
<b>IP VPS   :</b> <code>$MYIP</code>
<b>ISP      :</b> <code>$ISP</code>
<b>Lokasi   :</b> <code>$CITY</code>
<b>Swap RAM :</b> <code>$SWAP_MSG</code>
<b>Waktu    :</b> <code>$DATE</code>
<code>---------------------------</code>
<i>Auto Script by AcilShop</i>
"

# Kirim Pesan
curl -s --max-time 10 -d "chat_id=$ADMIN_ID&disable_web_page_preview=1&parse_mode=html&text=$TG_MSG" https://api.telegram.org/bot$BOT_TOKEN/sendMessage > /dev/null

# Hapus file setup
rm -f setup.sh > /dev/null 2>&1

# Tampilan Akhir
clear
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}      INSTALASI SELESAI               ${NC}"
echo -e "${GREEN}======================================${NC}"
echo -e "Domain : ${YELLOW}$DOMAIN${NC}"
echo -e "Swap   : ${YELLOW}$SWAP_MSG${NC}"
echo -e "Status : ${GREEN}VERIFIED (ACILSHOP PREMIUM)${NC}"
echo -e "Ketik ${YELLOW}menu${NC} untuk mengelola user."
