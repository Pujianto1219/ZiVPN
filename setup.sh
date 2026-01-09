#!/bin/bash
# ZiVPN Auto Installer (All-in-One)
# Features: Domain Input, Silent Install (No Password), Custom Cert, Embedded Menu

# --- 1. Persiapan & Input Domain ---
export DEBIAN_FRONTEND=noninteractive
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${YELLOW}Initial Setup ZiVPN...${NC}"

# Buat folder dulu
mkdir -p /etc/zivpn > /dev/null 2>&1

# === INPUT DOMAIN (Wajib di awal) ===
echo -e "${GREEN}=============================================${NC}"
echo -e "${YELLOW}           KONFIGURASI DOMAIN                ${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "Masukkan domain yang sudah dipointing ke IP VPS ini."
echo -e "Contoh: vpn.domainku.com"
echo -e "Jika kosong, otomatis menggunakan IP Address."
echo ""
read -p "Domain: " domain_input

# Logika penentuan domain
if [ -z "$domain_input" ]; then
    echo -e "${RED}Domain tidak diisi, menggunakan IP Address...${NC}"
    DOMAIN=$(curl -s ifconfig.me)
else
    DOMAIN="$domain_input"
fi

# Simpan domain ke file (agar Menu bisa baca nanti)
echo "$DOMAIN" > /etc/zivpn/domain
echo -e "${GREEN}Domain disimpan: $DOMAIN${NC}"
sleep 2

# --- 2. Install Dependencies (Silent) ---
echo -e "${YELLOW}Installing Dependencies...${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install -y jq curl wget git zip unzip openssl python3 python3-pip > /dev/null 2>&1

# Stop service lama jika ada
systemctl stop zivpn.service > /dev/null 2>&1

# --- 3. Download Binary (Auto Detect Arch) ---
echo -e "${YELLOW}Downloading Core Service...${NC}"
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    wget -q https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
elif [[ "$ARCH" == "aarch64" ]]; then
    wget -q https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-arm64 -O /usr/local/bin/zivpn
else
    echo -e "${RED}Arsitektur $ARCH tidak didukung!${NC}"
    exit 1
fi
chmod +x /usr/local/bin/zivpn

# --- 4. Buat Config Kosong (Tanpa Password) ---
# Ini kuncinya agar tidak ada prompt password. List user dibuat kosong [].
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

# --- 5. Generate Sertifikat SSL (Sesuai Domain) ---
echo -e "${YELLOW}Generating SSL Cert for $DOMAIN...${NC}"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=ID/ST=JKT/L=JKT/O=ZiVPN/OU=VPN/CN=$DOMAIN" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" > /dev/null 2>&1

# Tuning Network
sysctl -w net.core.rmem_max=16777216 > /dev/null 2>&1
sysctl -w net.core.wmem_max=16777216 > /dev/null 2>&1

# --- 6. Buat Service Systemd ---
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

# --- 7. EMBEDDED MENU SCRIPT ---
# Menu langsung dibuat di sini agar tidak perlu download file terpisah
echo -e "${YELLOW}Installing Menu...${NC}"
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

# Load Domain
if [ -f "$DOMAIN_FILE" ]; then
    DOMAIN=$(cat "$DOMAIN_FILE")
else
    DOMAIN=$(curl -s ifconfig.me)
fi

# Cek JQ
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
    fi
    read -n 1 -s -r -p "Tekan tombol untuk kembali..."
}

trial_user() {
    echo -e "\n${YELLOW}=== TRIAL USER ===${NC}"
    trial_pass="trial$(shuf -i 1000-9999 -n 1)"
    jq --arg pass "$trial_pass" '.auth.config += [$pass]' $CONFIG_FILE > /tmp/config.tmp && mv /tmp/config.tmp $CONFIG_FILE
    systemctl restart zivpn
    echo -e "${GREEN}Trial Created: $trial_pass${NC}"
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
           wget -q -O ziun.sh https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/uninstall.sh
           chmod +x ziun.sh && ./ziun.sh
           exit 0 ;;
        x) exit 0 ;;
        *) echo "Salah pilih"; sleep 1 ;;
    esac
done
EOF
chmod +x /usr/bin/menu

# --- 8. Start Service & Cleanup ---
systemctl enable zivpn.service > /dev/null 2>&1
systemctl start zivpn.service > /dev/null 2>&1

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
echo -e "Cert   : ${YELLOW}/etc/zivpn/zivpn.crt${NC}"
echo -e "Ketik ${YELLOW}menu${NC} untuk mulai."
