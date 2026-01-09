#!/bin/bash
# Zivpn UDP Installer (Separated Bot File)
# Mode: Silent Install + Empty Config + Menu Download

# --- 0. Persiapan Non-Interactive ---
export DEBIAN_FRONTEND=noninteractive

# --- 1. Update & Install Dependencies ---
echo -e "Updating server & Installing Dependencies..."
apt-get update -y > /dev/null 2>&1
# Kita install python3-pip di awal agar siap pakai
apt-get install -y jq curl wget git zip unzip openssl python3 python3-pip > /dev/null 2>&1

# Stop service jika ada
systemctl stop zivpn.service > /dev/null 2>&1
systemctl stop zibot.service > /dev/null 2>&1

# --- 2. Download Binary (AMD64) ---
echo -e "Downloading UDP Service..."
wget -q https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

mkdir -p /etc/zivpn > /dev/null 2>&1

# --- 3. MEMBUAT CONFIG.JSON (KOSONG) ---
echo -e "Creating Empty Config File..."
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

# --- 4. Generate Sertifikat SSL ---
echo "Generating cert files..."
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=US/ST=California/L=Los Angeles/O=Zivpn/OU=IT/CN=zivpn" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" > /dev/null 2>&1

# Tuning Network
sysctl -w net.core.rmem_max=16777216 > /dev/null 2>&1
sysctl -w net.core.wmem_max=16777216 > /dev/null 2>&1

# --- 5. Membuat Service VPN Systemd ---
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

# --- 6. MEMBUAT SCRIPT MENU (Embedded) ---
cat << 'EOF' > /usr/bin/menu
#!/bin/bash

CONFIG_FILE="/etc/zivpn/config.json"
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# Auto install JQ jika hilang
if ! command -v jq &> /dev/null; then apt-get install jq -y > /dev/null 2>&1; fi

show_header() {
    clear
    echo -e "${CYAN}============================================${NC}"
    echo -e "${YELLOW}           ZiVPN SERVER MANAGER            ${NC}"
    echo -e "${CYAN}============================================${NC}"
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

setup_bot() {
    echo -e "\n${YELLOW}=== SETUP TELEGRAM BOT ===${NC}"
    echo -e "Pastikan Anda sudah upload file bot.py ke GitHub Anda."
    echo ""
    read -p "Masukkan Bot Token : " BOT_TOKEN
    read -p "Masukkan ID Admin  : " ADMIN_ID
    
    if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ]; then
        echo -e "${RED}Data tidak boleh kosong!${NC}"; sleep 2; return
    fi

    echo -e "${YELLOW}Install Dependencies...${NC}"
    pip3 install pyTelegramBotAPI --break-system-packages > /dev/null 2>&1 || pip3 install pyTelegramBotAPI > /dev/null 2>&1

    echo -e "${YELLOW}Downloading Bot Script...${NC}"
    # PENTING: Ganti URL di bawah ini dengan URL Raw bot.py punya Anda sendiri
    wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/bot.py -O /etc/zivpn/bot.py

    echo -e "${YELLOW}Configuring Bot...${NC}"
    # Mengganti placeholder di bot.py dengan input user
    sed -i "s/DATA_TOKEN/$BOT_TOKEN/g" /etc/zivpn/bot.py
    sed -i "s/DATA_ADMIN/$ADMIN_ID/g" /etc/zivpn/bot.py

    echo -e "${YELLOW}Creating Service...${NC}"
    cat << EOF_SVC > /etc/systemd/system/zibot.service
[Unit]
Description=ZiVPN Telegram Bot
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /etc/zivpn/bot.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF_SVC

    systemctl daemon-reload
    systemctl enable zibot
    systemctl restart zibot
    
    echo -e "${GREEN}Bot Berhasil Diinstall! Ketik /start di bot.${NC}"
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
    echo -e "[7] Setup Bot Telegram"
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
        7) setup_bot ;;
        x) exit 0 ;;
        *) echo "Salah pilih"; sleep 1 ;;
    esac
done
EOF

chmod +x /usr/bin/menu

# --- 7. Start Services & Firewall ---
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
echo -e "Ketik ${YELLOW}menu${NC} lalu pilih ${YELLOW}[7]${NC} untuk install Bot."
