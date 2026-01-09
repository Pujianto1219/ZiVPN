#!/bin/bash
# Zivpn UDP Installer
# Mode: Input Domain + Empty Config + Menu

# --- 0. Persiapan & Warna ---
export DEBIAN_FRONTEND=noninteractive
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${YELLOW}Updating server & Installing Dependencies...${NC}"

# --- 1. Update & Install Dependencies ---
apt-get update -y > /dev/null 2>&1
apt-get install -y jq curl wget git zip unzip openssl python3 python3-pip > /dev/null 2>&1

# Stop service jika ada
systemctl stop zivpn.service > /dev/null 2>&1
systemctl stop zibot.service > /dev/null 2>&1

# --- 2. INPUT DOMAIN ---
mkdir -p /etc/zivpn > /dev/null 2>&1
clear
echo -e "${GREEN}=============================================${NC}"
echo -e "${YELLOW}           KONFIGURASI DOMAIN                ${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "Silakan masukkan domain yang sudah dipointing ke IP ini."
echo -e "Contoh: vpn.domainku.com"
echo ""
read -p "Masukkan Domain: " domain

# Validasi jika kosong, pakai IP
if [ -z "$domain" ]; then
    echo -e "${RED}Domain tidak diisi, menggunakan IP Server...${NC}"
    domain=$(curl -s ifconfig.me)
fi

# Simpan domain ke file agar menu bisa baca
echo "$domain" > /etc/zivpn/domain
echo -e "${GREEN}Domain diset ke: $domain${NC}"
sleep 2

# --- 3. Download Binary (AMD64) ---
echo -e "${YELLOW}Downloading UDP Service...${NC}"
wget -q https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

# --- 4. MEMBUAT CONFIG.JSON (KOSONG) ---
echo -e "${YELLOW}Creating Config File...${NC}"
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

# --- 5. Generate Sertifikat SSL (Sesuai Domain) ---
echo -e "${YELLOW}Generating cert files for $domain...${NC}"
# Perhatikan bagian CN=$domain, ini membuat sertifikat sesuai domain inputan
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=ID/ST=Jakarta/L=Jakarta/O=ZiVPN/OU=VPN/CN=$domain" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" > /dev/null 2>&1

# Tuning Network
sysctl -w net.core.rmem_max=16777216 > /dev/null 2>&1
sysctl -w net.core.wmem_max=16777216 > /dev/null 2>&1

# --- 6. Membuat Service Systemd ---
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

# --- 7. MEMBUAT SCRIPT MENU (Embedded) ---
cat << 'EOF' > /usr/bin/menu
#!/bin/bash

CONFIG_FILE="/etc/zivpn/config.json"
DOMAIN_FILE="/etc/zivpn/domain"
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# Ambil Domain
if [ -f "$DOMAIN_FILE" ]; then
    DOMAIN=$(cat "$DOMAIN_FILE")
else
    DOMAIN=$(curl -s ifconfig.me)
fi

if ! command -v jq &> /dev/null; then apt-get install jq -y > /dev/null 2>&1; fi

show_header() {
    clear
    echo -e "${CYAN}============================================${NC}"
    echo -e "${YELLOW}           ZiVPN SERVER MANAGER            ${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo -e "${WHITE} Domain    : ${GREEN}$DOMAIN${NC}"
    echo -e "${WHITE} IP Server : ${YELLOW}$(curl -s ifconfig.me)${NC}"
    TOTAL=$(jq '.auth.config | length' $CONFIG_FILE 2>/dev/null || echo "0")
    echo -e "${WHITE} Total User: ${YELLOW}$TOTAL${NC}"
    
    # Cek Status Bot
    if systemctl is-active --quiet zibot; then
        echo -e "${WHITE} Status Bot: ${GREEN}RUNNING${NC}"
    else
        echo -e "${WHITE} Status Bot: ${RED}NOT RUNNING${NC}"
    fi
    echo -e "${CYAN}============================================${NC}"
}

add_user() {
    echo -e "\n${YELLOW}=== TAMBAH USER ===${NC}"
    read -p "Masukkan Password Baru : " new_pass
    if [ -z "$new_pass" ]; then echo "Password kosong!"; sleep 1; return; fi
    if jq -e ".auth.config[] | select(. == \"$new_pass\")" $CONFIG_FILE > /dev/null 2>&1; then
        echo -e "${RED}Error: Password sudah ada!${NC}"
    else
        jq --arg pass "$new_pass" '.auth.config += [$pass]' $CONFIG_FILE > /tmp/config.tmp && mv /tmp/config.tmp $CONFIG_FILE
        systemctl restart zivpn
        echo -e "${GREEN}Sukses menambah user: $new_pass${NC}"
        echo -e "Detail:"
        echo -e "Domain: $DOMAIN"
        echo -e "Pass  : $new_pass"
    fi
    read -n 1 -s -r -p "Tekan tombol untuk kembali..."
}

trial_user() {
    echo -e "\n${YELLOW}=== TRIAL USER ===${NC}"
    trial_pass="trial$(shuf -i 1000-9999 -n 1)"
    jq --arg pass "$trial_pass" '.auth.config += [$pass]' $CONFIG_FILE > /tmp/config.tmp && mv /tmp/config.tmp $CONFIG_FILE
    systemctl restart zivpn
    echo -e "${GREEN}Trial Created!${NC}"
    echo -e "Domain : $DOMAIN"
    echo -e "Pass   : $trial_pass"
    read -n 1 -s -r -p "Tekan tombol untuk kembali..."
}

del_user() {
    echo -e "\n${YELLOW}=== HAPUS USER ===${NC}"
    jq -r '.auth.config[]' $CONFIG_FILE
    echo ""
    read -p "Masukkan Password yg dihapus: " del_pass
    if jq -e ".auth.config[] | select(. == \"$del_pass\")" $CONFIG_FILE > /dev/null 2>&1; then
        jq --arg pass "$del_pass" '.auth.config -= [$pass]' $CONFIG_FILE > /tmp/config.tmp && mv /tmp/config.tmp $CONFIG_FILE
        systemctl restart zivpn
        echo -e "${GREEN}User dihapus.${NC}"
    else
        echo -e "${RED}User tidak ditemukan.${NC}"
    fi
    read -n 1 -s -r -p "Tekan tombol untuk kembali..."
}

list_user() {
    echo -e "\n${YELLOW}=== LIST USER ===${NC}"
    LEN=$(jq '.auth.config | length' $CONFIG_FILE)
    if [ "$LEN" -eq 0 ]; then echo -e "${RED}(Belum ada user)${NC}"; else jq -r '.auth.config[]' $CONFIG_FILE; fi
    echo -e "-------------------------------"
    read -n 1 -s -r -p "Kembali..."
}

setup_bot() {
    echo -e "\n${YELLOW}=== SETUP TELEGRAM BOT ===${NC}"
    echo -e "Setup bot dinonaktifkan sementara (Manual Mode)."
    # (Kode bot dihapus sesuai permintaan 'skip dulu')
    read -n 1 -s -r -p "Tekan tombol untuk kembali..."
}

while true; do
    show_header
    echo -e "[1] Tambah User"
    echo -e "[2] Trial User"
    echo -e "[3] Hapus User"
    echo -e "[4] Lihat User"
    echo -e "[5] Restart Service"
    echo -e "[6] Uninstall"
    echo -e "[x] Exit"
    read -p "Pilih: " opt
    case $opt in
        1) add_user ;;
        2) trial_user ;;
        3) del_user ;;
        4) list_user ;;
        5) systemctl restart zivpn; echo "Done."; sleep 1 ;;
        6) 
           echo "Uninstalling..."
           systemctl stop zibot 2>/dev/null
           systemctl disable zibot 2>/dev/null
           rm /etc/systemd/system/zibot.service 2>/dev/null
           wget -q -O ziun.sh https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/uninstall.sh
           chmod +x ziun.sh && ./ziun.sh
           exit 0 ;;
        x) exit 0 ;;
        *) echo "Salah pilih"; sleep 1 ;;
    esac
done
EOF

chmod +x /usr/bin/menu

# --- 8. Start Services & Firewall ---
systemctl enable zivpn.service > /dev/null 2>&1
systemctl start zivpn.service > /dev/null 2>&1

IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp > /dev/null 2>&1
ufw allow 5667/udp > /dev/null 2>&1

rm -f zi.* > /dev/null 2>&1

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}      INSTALASI SELESAI               ${NC}"
echo -e "${GREEN}======================================${NC}"
echo -e "Domain : ${YELLOW}$domain${NC}"
echo -e "Ketik ${YELLOW}menu${NC} untuk kelola server."
