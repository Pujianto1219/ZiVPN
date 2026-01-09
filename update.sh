#!/bin/bash
# ==========================================
#  ZiVPN SAFE UPDATER
#  Overwrite Mode (Tidak menghapus jika gagal download)
# ==========================================

# --- CEK KONEKSI (Safety First) ---
wget -q --spider https://google.com
if [ $? -ne 0 ]; then
    echo -e "\033[0;31m[ERROR] Tidak ada koneksi internet. Update dibatalkan.\033[0m"
    exit 1
fi

dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
biji=`date +"%Y-%m-%d" -d "$dateFromServer"`

###########- COLOR CODE -##############
colornow=$(cat /etc/rmbl/theme/color.conf 2>/dev/null)
NC="\e[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
WH='\033[1;37m'
# Fallback colors if theme config missing
COLOR1="${CYAN}"
COLBG1="${NC}"
###########- END COLOR CODE -##########

clear
echo -e "${CYAN}┌─────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${YELLOW}           ⇱ UPDATE SCRIPT ZIVPN ⇲             ${NC} ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ${YELLOW}          ⇱  METODE: OVERWRITE  ⇲             ${NC} ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────┘${NC}"

# --- FUNGSI UPDATE FILE (AMAN) ---
update_file() {
    local url="$1"
    local target="$2"
    local temp_file="/tmp/zivpn_temp"

    # 1. Download ke file sementara dulu
    wget -q -O "$temp_file" "$url"

    # 2. Cek apakah download sukses & file ada isinya
    if [ -s "$temp_file" ]; then
        # Jika sukses, timpa file lama dengan yang baru
        mv "$temp_file" "$target"
        chmod +x "$target"
        # Fix format Windows (\r) jika ada
        sed -i 's/\r$//' "$target"
    else
        # Jika gagal, hapus file sementara & biarkan file lama tetap ada
        rm -f "$temp_file"
    fi
}

# --- FUNGSI UTAMA (PROSES UPDATE) ---
res1() {
    # URL REPO ANDA
    REPO="https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main"
    REPO_UTILS="${REPO}/Utils"
    
    cd /usr/bin

    # === MULAI UPDATE FILE ===
    # Script tidak menghapus file lama, tapi langsung menimpa (overwrite)
    # Jika link mati/gagal, file lama Anda TETAP AMAN.

    # 1. Menu Utama
    update_file "${REPO}/menu.sh" "/usr/bin/menu"

    # 2. Script XP (Dari folder Utils di Github)
    update_file "${REPO_UTILS}/xp-trial.sh" "/usr/bin/xp-trial"
    update_file "${REPO_UTILS}/xp-user.sh" "/usr/bin/xp-user"

    # 3. Script Pendukung (Update & Uninstall)
    update_file "${REPO}/update.sh" "/usr/bin/update"
    update_file "${REPO}/uninstall.sh" "/usr/bin/uninstall"

    # 4. Refresh Cronjob (Agar perubahan jadwal XP diterapkan)
    # Hapus cron lama (aman dilakukan karena akan ditulis ulang)
    rm -f /etc/cron.d/xp_trial /etc/cron.d/xp_user
    
    # Tulis ulang cronjob
    echo "*/10 * * * * root /usr/bin/xp-trial" > /etc/cron.d/xp_trial
    echo "0 0 * * * root /usr/bin/xp-user" > /etc/cron.d/xp_user
    echo "0 5 * * * root reboot" > /etc/cron.d/auto_reboot
    
    service cron restart > /dev/null 2>&1
}

# --- LOADING BAR ANIMATION ---
fun_bar() {
    CMD[0]="$1"
    CMD[1]="$2"
    (
        [[ -e $HOME/fim ]] && rm $HOME/fim
        ${CMD[0]} -y >/dev/null 2>&1
        ${CMD[1]} -y >/dev/null 2>&1
        touch $HOME/fim
    ) >/dev/null 2>&1 &
    
    tput civis
    echo -ne "  \033[0;33mChecking & Updating \033[1;37m- \033[0;33m["
    while true; do
        for ((i = 0; i < 18; i++)); do
            echo -ne "\033[0;32m#"
            sleep 0.1s
        done
        [[ -e $HOME/fim ]] && rm $HOME/fim && break
        echo -e "\033[0;33m]"
        sleep 1s
        tput cuu1
        tput dl1
        echo -ne "  \033[0;33mChecking & Updating \033[1;37m- \033[0;33m["
    done
    echo -e "\033[0;33m]\033[1;37m -\033[1;32m COMPLETED !\033[1;37m"
    tput cnorm
}

# --- EKSEKUSI ---
echo -e ""
echo -e "  \033[1;91m Syncing with GitHub...\033[1;37m"
fun_bar 'res1'

echo -e ""
echo -e "${GREEN} Update Selesai.${NC}"
echo -e "${YELLOW} File lama yang gagal didownload tidak berubah.${NC}"
echo -e ""
read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali ke Menu..."
menu    local temp="/tmp/zivpn_temp_file"

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
