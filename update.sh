#!/bin/bash
# ==========================================
#  SCRIPT UPDATER ZIVPN (FIXED PATH)
#  Repo: https://github.com/Pujianto1219/ZiVPN
# ==========================================

# --- WARNA TEXT ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- KONFIGURASI URL ---
# URL Utama
REPO_ROOT="https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main"
# URL Folder Utils (Tempat script XP berada)
REPO_UTILS="${REPO_ROOT}/Utils"

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}           UPDATE SYSTEM ZIVPN ACILSHOP         ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Memulai proses update..."
sleep 1

# FUNGSI DOWNLOAD AMAN (Cek dulu sebelum timpa)
download_safe() {
    local url="$1"
    local dest="$2"
    local temp="/tmp/zivpn_temp_file"

    echo -n "Update $(basename $dest)... "
    
    # Download ke file temp dulu
    wget -q "$url" -O "$temp"
    
    # Cek apakah download sukses & file ada isinya
    if [ -s "$temp" ]; then
        mv "$temp" "$dest"
        chmod +x "$dest"
        echo -e "${GREEN}[OK]${NC}"
    else
        echo -e "${RED}[GAGAL]${NC}"
        echo -e "${RED}    -> Sumber tidak ditemukan: $url${NC}" 
        rm -f "$temp"
    fi
}

# 1. FIX TIMEZONE
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# 2. DOWNLOAD SCRIPT
echo -e "${GREEN}[1/4] Mengunduh Script Terbaru...${NC}"

# Menu ada di Root (Halaman Depan)
download_safe "${REPO_ROOT}/menu.sh" "/usr/bin/menu"

# Script XP ada di folder Utils
# Pastikan nama file di GitHub Anda: xp-trial.sh dan xp-user.sh
download_safe "${REPO_UTILS}/xp-trial.sh" "/usr/bin/xp-trial"
download_safe "${REPO_UTILS}/xp-user.sh" "/usr/bin/xp-user"

# 3. FIX DATABASE & CRONJOB
echo -e "${GREEN}[2/4] Memperbarui Database & Cron...${NC}"

mkdir -p /etc/zivpn
[ ! -f "/etc/zivpn/user.db" ] && touch /etc/zivpn/user.db
[ ! -f "/etc/zivpn/trial.db" ] && touch /etc/zivpn/trial.db

# Reset Cronjob
rm -f /etc/cron.d/xp_trial /etc/cron.d/xp_user /etc/cron.d/auto_reboot
echo "*/10 * * * * root /usr/bin/xp-trial" > /etc/cron.d/xp_trial
echo "0 0 * * * root /usr/bin/xp-user" > /etc/cron.d/xp_user
echo "0 5 * * * root reboot" > /etc/cron.d/auto_reboot
service cron restart > /dev/null 2>&1

# 4. OPTIMASI KERNEL
echo -e "${GREEN}[3/4] Optimasi Kernel...${NC}"
if ! grep -q "bbr" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p > /dev/null 2>&1
fi

# 5. RESTART
echo -e "${GREEN}[4/4] Restarting Services...${NC}"
systemctl restart zivpn
echo 3 > /proc/sys/vm/drop_caches

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}           UPDATE SELESAI!            ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Silakan ketik ${YELLOW}menu${NC}"
