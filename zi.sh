#!/bin/bash
# Zivpn UDP Module installer
# Creator Zahid Islam
# Modified with Embedded Menu

# --- 1. Update & Install Dependencies (Termasuk JQ) ---
echo -e "Updating server & Installing Dependencies..."
sudo apt-get update && apt-get upgrade -y
# JQ wajib diinstall untuk memproses JSON di menu nanti
sudo apt-get install -y jq curl wget git zip unzip

systemctl stop zivpn.service 1> /dev/null 2> /dev/null

# --- 2. Download Binary (AMD64) ---
echo -e "Downloading UDP Service"
wget https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
chmod +x /usr/local/bin/zivpn

mkdir -p /etc/zivpn 1> /dev/null 2> /dev/null
wget https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/config.json -O /etc/zivpn/config.json 1> /dev/null 2> /dev/null

# --- 3. Generate Cert & Tuning ---
echo "Generating cert files:"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null

sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

# --- 4. Create Service ---
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

# --- 5. Initial Password Setup ---
echo -e "ZIVPN UDP Passwords"
read -p "Enter passwords separated by commas, example: pass1,pass2 (Press enter for Default 'zi'): " input_config

if [ -n "$input_config" ]; then
    IFS=',' read -r -a config <<< "$input_config"
    if [ ${#config[@]} -eq 1 ]; then
        config+=(${config[0]})
    fi
else
    config=("zi")
fi

new_config_str="\"config\": [$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')]"
sed -i -E "s/\"config\": ?\[[[:space:]]*\"zi\"[[:space:]]*\]/${new_config_str}/g" /etc/zivpn/config.json

# --- 6. MEMBUAT SCRIPT MENU OTOMATIS (EMBEDDED) ---
echo "Creating Menu Script..."
cat << 'EOF' > /usr/bin/menu
#!/bin/bash

CONFIG_FILE="/etc/zivpn/config.json"
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

if ! command -v jq &> /dev/null; then
    echo "Installing JQ..."
    apt-get install jq -y
fi

show_header() {
    clear
    echo -e "${CYAN}============================================${NC}"
    echo -e "${YELLOW}           ZiVPN SERVER MANAGER            ${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo -e "${WHITE} IP Server : ${YELLOW}$(curl -s ifconfig.me)${NC}"
    TOTAL=$(jq '.auth.config | length' $CONFIG_FILE 2>/dev/null || echo "0")
    echo -e "${WHITE} Total User: ${YELLOW}$TOTAL${NC}"
    echo -e "${CYAN}============================================${NC}"
}

add_user() {
    echo -e "\n${YELLOW}=== TAMBAH USER ===${NC}"
    read -p "Masukkan Password Baru : " new_pass
    if jq -e ".auth.config[] | select(. == \"$new_pass\")" $CONFIG_FILE > /dev/null; then
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
    if jq -e ".auth.config[] | select(. == \"$del_pass\")" $CONFIG_FILE > /dev/null; then
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
    jq -r '.auth.config[]' $CONFIG_FILE
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
# --- BATAS AKHIR SCRIPT MENU ---

chmod +x /usr/bin/menu

# --- 7. Start Services & Firewall ---
systemctl enable zivpn.service
systemctl start zivpn.service

IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp
ufw allow 5667/udp
rm zi.* 1> /dev/null 2> /dev/null

echo -e "ZIVPN UDP Installed"
echo -e "Ketik command ${YELLOW}menu${NC} untuk mengelola server."
