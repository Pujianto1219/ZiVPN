#!/bin/bash

# ==========================================================
#  SCRIPT INSTALLER: FIX IP VALIDATION & DOMAIN
# ==========================================================

# --- WARNA TEXT ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- 1. INSTALL DEPENDENCIES AWAL ---
# Kita butuh curl dan dnsutils segera
apt-get update -y > /dev/null 2>&1
apt-get install dnsutils curl -y > /dev/null 2>&1

# --- 2. PERSIAPAN VARIABEL IP ---
# Mengambil IP dan membuang spasi/karakter newline yg tidak perlu
MYIP=$(curl -sS ipv4.icanhazip.com | tr -d '\r' | tr -d ' ')

# ==========================================================
#  FUNGSI VALIDASI IZIN (DIPERBAIKI)
# ==========================================================
function check_license() {
    # GANTI URL INI DENGAN URL RAW GITHUB ANDA
    IZIN_URL="https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/ip"
    
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           MEMERIKSA LISENSI SERVER...          ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "IP Anda saat ini : ${GREEN}$MYIP${NC}"
    echo -e "Sedang mencocokkan dengan database..."
    
    # 1. Ambil data, bersihkan karakter Windows (\r), lalu cari IP spesifik
    #    grep -E "^$MYIP" artinya: Cari baris yang DIAWALI dengan IP kita.
    #    Ini mencegah IP 1.1.1.1 lolos jika yang terdaftar 1.1.1.10
    
    REPO_DATA=$(curl -sS --max-time 10 "$IZIN_URL" | tr -d '\r')
    
    # Cek apakah repo bisa diakses
    if [[ -z "$REPO_DATA" ]]; then
        echo -e "${RED}[ERROR] Gagal terhubung ke database izin!${NC}"
        echo -e "Pastikan URL Raw Github benar/internet lancar."
        exit 1
    fi

    # Filter data user dari database
    # Mencari baris yang dimulai dengan IP user dan diikuti pemisah '|'
    USER_DATA=$(echo "$REPO_DATA" | grep -E "^$MYIP\|")

    # 2. Logika Validasi Ketat
    if [[ -n "$USER_DATA" ]]; then
        # Jika data ditemukan (String tidak kosong)
        IFS='|' read -r REGISTERED_IP EXPIRED_DATE <<< "$USER_DATA"
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "STATUS IP   : ${GREEN}TERDAFTAR (PREMIUM)${NC}"
        echo -e "MASA AKTIF  : ${GREEN}$EXPIRED_DATE${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}Akses Diterima. Melanjutkan...${NC}"
        sleep 2
    else
        # Jika data tidak ditemukan
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "STATUS IP   : ${RED}TIDAK TERDAFTAR / AKSES DITOLAK${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "IP ${RED}$MYIP${NC} belum terdaftar di sistem kami."
        echo -e "Silakan hubungi Admin AcilShop untuk order."
        
        # Hapus script agar user tidak bisa mengakalinya (Opsional)
        # rm -f setup.sh
        
        exit 1  # MEMAKSA SCRIPT BERHENTI DISINI
    fi
}

# ==========================================================
#  FUNGSI VALIDASI DOMAIN (LOOPING)
# ==========================================================
function check_domain_pointing() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}           KONFIGURASI DOMAIN SERVER            ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "IP VPS Anda : ${GREEN}$MYIP${NC}"
    echo -e "Silakan masukkan domain yang sudah dipointing."
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    while true; do
        echo -n -e "Input Domain: ${GREEN}"
        read input_domain
        echo -e "${NC}"
        
        # Bersihkan spasi input user
        DOMAIN=$(echo "$input_domain" | xargs)

        if [[ -z "$DOMAIN" ]]; then
            echo -e "${RED}[ERROR] Domain tidak boleh kosong!${NC}"
            continue
        fi

        echo -e "${YELLOW}[PROCESS] Memeriksa DNS $DOMAIN...${NC}"
        # Ambil IP asli dari domain
        domain_ip=$(dig +short "$DOMAIN" | head -n1)
        
        # Validasi
        if [[ "$domain_ip" == "$MYIP" ]]; then
            echo -e "${GREEN}[SUKSES] Domain valid! ($DOMAIN -> $MYIP)${NC}"
            
            # Simpan Domain
            mkdir -p /root
            mkdir -p /etc/zivpn
            echo "$DOMAIN" > /root/domain
            echo "$DOMAIN" > /etc/zivpn/domain
            break # KELUAR DARI LOOP
            
        elif [[ -z "$domain_ip" ]]; then
             echo -e "${RED}[ERROR] Domain tidak ditemukan / DNS belum propagasi.${NC}"
             echo -e "Coba lagi..."
        else
            echo -e "${RED}[ERROR] Domain mengarah ke: $domain_ip${NC}"
            echo -e "${RED}        Seharusnya ke : $MYIP${NC}"
            echo -e "Pointing domain terlebih dahulu di Cloudflare!"
            echo -e "Sistem menunggu input ulang...\n"
        fi
        sleep 1
    done
}

# ==========================================================
#  EKSEKUSI UTAMA (URUTAN JANGAN DIBALIK)
# ==========================================================

# 1. Cek License WAJIB PERTAMA
check_license

# 2. Jika Lolos License, Baru Cek Domain
check_domain_pointing

# --- 3. LANJUT KE SWAP & SYSTEM ---
# (Kode di bawah ini hanya akan jalan jika check_license lolos)

function install_swap() {
    clear
    echo -e "${YELLOW}=============================================${NC}"
    echo -e "${CYAN}          KONFIGURASI SWAP RAM (VIRTUAL)     ${NC}"
    echo -e "${YELLOW}=============================================${NC}"
    echo -e "[1] 1 GB"
    echo -e "[2] 2 GB"
    echo -e "[3] 4 GB"
    echo -e "[x] Skip"
    read -p "Pilih: " swap_pilih

    case $swap_pilih in
        1) SWAP_SIZE=1048576; SWAP_MSG="1GB" ;;
        2) SWAP_SIZE=2097152; SWAP_MSG="2GB" ;;
        3) SWAP_SIZE=4194304; SWAP_MSG="4GB" ;;
        x|X) SWAP_SIZE=0; SWAP_MSG="SKIP" ;;
        *) SWAP_SIZE=1048576; SWAP_MSG="1GB" ;;
    esac

    if [ $SWAP_SIZE -gt 0 ]; then
        echo -e "${CYAN}Membuat Swap $SWAP_MSG...${NC}"
        swapoff -a >/dev/null 2>&1
        rm -f /swapfile
        dd if=/dev/zero of=/swapfile bs=1024 count=$SWAP_SIZE > /dev/null 2>&1
        chmod 600 /swapfile
        mkswap /swapfile > /dev/null 2>&1
        swapon /swapfile > /dev/null 2>&1
        echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
    fi
}
install_swap

# --- 4. INSTALL CORE ---
clear
echo -e "${YELLOW}[Install] Menginstall Komponen Utama...${NC}"
apt-get install -y jq curl wget git zip unzip openssl python3 python3-pip cron socat netfilter-persistent iptables-persistent > /dev/null 2>&1

mkdir -p /usr/local/bin
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    wget -q https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
elif [[ "$ARCH" == "aarch64" ]]; then
    wget -q https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-arm64 -O /usr/local/bin/zivpn
fi
chmod +x /usr/local/bin/zivpn

# Download Script XP
wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/xp-trial.sh -O /usr/bin/xp-trial
wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/xp-user.sh -O /usr/bin/xp-user

chmod +x /usr/bin/xp-trial
chmod +x /usr/bin/xp-user

# Buat Database Kosong (Agar tidak error saat pertama run)
touch /etc/zivpn/trial.db
touch /etc/zivpn/user.db

# --- SETTING CRONJOB TERPISAH ---
# 1. XP Trial: Cek setiap 10 menit
echo "*/10 * * * * root /usr/bin/xp-trial" > /etc/cron.d/xp_trial

# 2. XP User: Cek setiap jam 12 malam (00:00)
echo "0 0 * * * root /usr/bin/xp-user" > /etc/cron.d/xp_user

# 3. Auto Reboot: Cek jam 05:00 Pagi (WIB) - Opsional, maintenance harian
echo "0 5 * * * root reboot" > /etc/cron.d/auto_reboot

service cron restart

# --- 5. CONFIG & SSL ---
mkdir -p /etc/zivpn
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

openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=ID/ST=JKT/L=JKT/O=ZiVPN/OU=VPN/CN=$DOMAIN" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" > /dev/null 2>&1

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
NoNewPrivileges=true
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

# Menu
wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/menu.sh -O /usr/bin/menu
chmod +x /usr/bin/menu

# Start
systemctl daemon-reload
systemctl enable zivpn.service > /dev/null 2>&1
systemctl start zivpn.service > /dev/null 2>&1

# Firewall
IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
netfilter-persistent save > /dev/null 2>&1
netfilter-persistent reload > /dev/null 2>&1

# Auto Reboot
echo "0 5 * * * root reboot" > /etc/cron.d/auto_reboot

# --- 6. TELEGRAM NOTIF ---
BOT_TOKEN="8194078306:AAGcRbkEStZeHFd2Fj6e8p8c_YPUrXHl1dw"
ADMIN_ID="6355497501"
ISP=$(curl -s ipinfo.io/org)
CITY=$(curl -s ipinfo.io/city)
TG_MSG="
<code>---------------------------</code>
<b>✅ INSTALLATION SUCCESS</b>
<code>---------------------------</code>
<b>Domain   :</b> <code>$DOMAIN</code>
<b>IP VPS   :</b> <code>$MYIP</code>
<b>ISP      :</b> <code>$ISP</code>
<b>Lokasi   :</b> <code>$CITY</code>
<b>Swap RAM :</b> <code>$SWAP_MSG</code>
<code>---------------------------</code>
<i>Auto Script by AcilShop</i>
"
curl -s --max-time 10 -d "chat_id=$ADMIN_ID&disable_web_page_preview=1&parse_mode=html&text=$TG_MSG" https://api.telegram.org/bot$BOT_TOKEN/sendMessage > /dev/null

rm -f setup.sh > /dev/null 2>&1
clear
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}      INSTALASI SELESAI               ${NC}"
echo -e "${GREEN}======================================${NC}"
echo -e "Domain : ${YELLOW}$DOMAIN${NC}"
echo -e "Status : ${GREEN}VERIFIED (ACILSHOP PREMIUM)${NC}"
echo -e "Ketik ${YELLOW}menu${NC} untuk mengelola user."
