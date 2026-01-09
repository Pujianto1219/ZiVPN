#!/bin/bash
# Zivpn UDP Module installer
# Modified for Auto Menu Integration

# --- Warna ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${YELLOW}Updating server & Installing Dependencies...${NC}"
sudo apt-get update && apt-get upgrade -y
# Tambah install 'jq' untuk memproses JSON di menu nanti
sudo apt-get install -y jq curl wget git zip unzip

systemctl stop zivpn.service 1> /dev/null 2> /dev/null

echo -e "${YELLOW}Downloading UDP Service...${NC}"
wget https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn 1> /dev/null 2> /dev/null
chmod +x /usr/local/bin/zivpn

mkdir -p /etc/zivpn 1> /dev/null 2> /dev/null
# Download Config Default
wget https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/config.json -O /etc/zivpn/config.json 1> /dev/null 2> /dev/null

echo -e "${YELLOW}Generating cert files...${NC}"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null

# Tuning Network
sysctl -w net.core.rmem_max=16777216 1> /dev/null 2> /dev/null
sysctl -w net.core.wmem_max=16777216 1> /dev/null 2> /dev/null

# Membuat Service Systemd
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

# --- INPUT PASSWORD AWAL ---
echo -e "${GREEN}ZIVPN UDP Passwords${NC}"
read -p "Masukkan password (pisahkan koma, cth: user1,user2): " input_config

if [ -n "$input_config" ]; then
    IFS=',' read -r -a config <<< "$input_config"
    if [ ${#config[@]} -eq 1 ]; then
        config+=(${config[0]})
    fi
else
    config=("zi")
fi

# Logic asli kamu untuk replace config awal
new_config_str="\"config\": [$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')]"
sed -i -E "s/\"config\": ?\[[[:space:]]*\"zi\"[[:space:]]*\]/${new_config_str}/g" /etc/zivpn/config.json

# --- ENABLE SERVICE & IPTABLES ---
systemctl enable zivpn.service
systemctl start zivpn.service

# Setup Iptables (Mengambil interface otomatis)
IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
# Simpan rule iptables agar permanen (opsional, butuh iptables-persistent)
# netfilter-persistent save 2>/dev/null

ufw allow 6000:19999/udp
ufw allow 5667/udp
rm zi.* 1> /dev/null 2> /dev/null

# --- DOWNLOAD MENU SCRIPT ---
echo -e "${YELLOW}Downloading Menu Script...${NC}"
wget -q -O /usr/bin/menu https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/menu.sh
chmod +x /usr/bin/menu

echo -e "${GREEN}ZIVPN UDP Installed!${NC}"
echo -e "Ketik ${YELLOW}menu${NC} untuk mengelola server."
