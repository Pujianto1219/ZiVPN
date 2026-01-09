#!/bin/bash
# Core Installer Script
# Fix: No Password Prompt & Use Domain from setup.sh

# Warna
YELLOW='\033[1;33m'
NC='\033[0m'

export DEBIAN_FRONTEND=noninteractive

# 1. Install Dependencies
echo -e "${YELLOW}[Core] Installing Dependencies...${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install -y jq curl wget git zip unzip openssl python3 python3-pip > /dev/null 2>&1

# Stop Service
systemctl stop zivpn.service > /dev/null 2>&1

# 2. Deteksi Arsitektur (AMD64 vs ARM64)
ARCH=$(uname -m)
echo -e "${YELLOW}[Core] Detected Architecture: $ARCH${NC}"

mkdir -p /etc/zivpn > /dev/null 2>&1

if [[ "$ARCH" == "x86_64" ]]; then
    # AMD64
    wget -q https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
elif [[ "$ARCH" == "aarch64" ]]; then
    # ARM64
    wget -q https://github.com/Pujianto1219/ZiVPN/releases/download/1.0/udp-zivpn-linux-arm64 -O /usr/local/bin/zivpn
else
    echo "Error: Arsitektur $ARCH tidak didukung!"
    exit 1
fi

chmod +x /usr/local/bin/zivpn

# 3. Buat Config Kosong (TANPA TANYA PASSWORD)
# Bagian ini otomatis membuat config dengan list user kosong []
echo -e "${YELLOW}[Core] Creating Empty Config...${NC}"
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

# 4. Generate SSL (Menggunakan Domain yang diinput di setup.sh)
# Script membaca file /etc/zivpn/domain yang dibuat oleh setup.sh
if [ -f "/etc/zivpn/domain" ]; then
    DOMAIN=$(cat /etc/zivpn/domain)
else
    DOMAIN=$(curl -s ifconfig.me)
fi

echo -e "${YELLOW}[Core] Generating SSL for $DOMAIN...${NC}"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=ID/ST=JKT/L=JKT/O=ZiVPN/OU=VPN/CN=$DOMAIN" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" > /dev/null 2>&1

# 5. Network Tuning
sysctl -w net.core.rmem_max=16777216 > /dev/null 2>&1
sysctl -w net.core.wmem_max=16777216 > /dev/null 2>&1

# 6. Service Systemd
echo -e "${YELLOW}[Core] Creating Service...${NC}"
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

# 7. Start & Firewall
systemctl enable zivpn.service > /dev/null 2>&1
systemctl start zivpn.service > /dev/null 2>&1

IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667
ufw allow 6000:19999/udp > /dev/null 2>&1
ufw allow 5667/udp > /dev/null 2>&1

rm -f /usr/local/bin/installer.sh # Bersih-bersih
