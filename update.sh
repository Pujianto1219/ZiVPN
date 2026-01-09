#!/bin/bash
# ==========================================
#  SCRIPT UPDATER ZIVPN (ALL-IN-ONE)
#  Repo: https://github.com/Pujianto1219/ZiVPN
# ==========================================

# --- WARNA TEXT ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- REPO SOURCE ---
# Pastikan file-file terbaru (menu.sh, xp-trial.sh, xp-user.sh) SUDAH diupload ke sini
REPO="https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main"

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}           UPDATE SYSTEM ZIVPN ACILSHOP         ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Memulai proses update..."
sleep 2

# 1. UPDATE DEPENDENCIES & TIMEZONE
echo -e "${GREEN}[1/5] Sinkronisasi System & Waktu...${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install curl wget jq -y > /dev/null 2>&1
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# 2. DOWNLOAD SCRIPT TERBARU (MENU & XP)
echo -e "${GREEN}[2/5] Mengunduh Script Menu & XP Terbaru...${NC}"

# Hapus file lama (bersih-bersih)
rm -f /usr/bin/menu
rm -f /usr/bin/xp
rm -f /usr/bin/xp-trial
rm -f /usr/bin/xp-user

# Download file baru dari Repo
wget -q "${REPO}/menu.sh" -O /usr/bin/menu
wget -q "${REPO}/xp-trial.sh" -O /usr/bin/xp-trial
wget -q "${REPO}/xp-user.sh" -O /usr/bin/xp-user

# Berikan izin eksekusi (chmod)
chmod +x /usr/bin/menu
chmod +x /usr/bin/xp-trial
chmod +x /usr/bin/xp-user

# 3. FIX DATABASE & CRONJOB
echo -e "${GREEN}[3/5] Memperbarui Database & Penjadwal (Cron)...${NC}"

# Pastikan folder config ada
mkdir -p /etc/zivpn

# Buat database kosong jika belum ada (Safe Mode)
# Agar menu baru tidak error saat baca database
if [ ! -f "/etc/zivpn/user.db" ]; then
    touch /etc/zivpn/user.db
fi
if [ ! -f "/etc/zivpn/trial.db" ]; then
    touch /etc/zivpn/trial.db
fi

# Reset Cronjob (Hapus yang lama, pasang yang baru)
rm -f /etc/cron.d/xp_trial
rm -f /etc/cron.d/xp_user
rm -f /etc/cron.d/xp
rm -f /etc/cron.d/auto_reboot

# Tulis Cronjob Baru (Split Trial & User)
echo "*/10 * * * * root /usr/bin/xp-trial" > /etc/cron.d/xp_trial
echo "0 0 * * * root /usr/bin/xp-user" > /etc/cron.d/xp_user
echo "0 5 * * * root reboot" > /etc/cron.d/auto_reboot

# Restart service cron
service cron restart > /dev/null 2>&1

# 4. OPTIMASI KERNEL (CPU & BBR)
echo -e "${GREEN}[4/5] Mengoptimalkan Kinerja Server...${NC}"

# Enable TCP BBR (Jika belum aktif)
if ! grep -q "bbr" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
fi

# Tuning Network Buffer (Agar tidak lag)
if ! grep -q "net.core.rmem_max" /etc/sysctl.conf; then
cat <<EOF >> /etc/sysctl.conf
fs.file-max = 1000000
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_tw_reuse = 1
EOF
fi

# Apply perubahan Kernel
sysctl -p > /dev/null 2>&1

# 5. FINALISASI
echo -e "${GREEN}[5/5] Restarting Services...${NC}"
systemctl restart zivpn
echo 3 > /proc/sys/vm/drop_caches

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}           UPDATE SELESAI! (SUCCESS)            ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Script Anda telah diperbarui ke versi terbaru."
echo -e ""
echo -e "Fitur Baru:"
echo -e "1. Tampilan Menu 3 Kolom (Compact)"
echo -e "2. Fix Auto Delete User & Trial"
echo -e "3. Optimasi CPU & Bandwidth (BBR)"
echo -e ""
echo -e "Silakan ketik ${YELLOW}menu${NC} untuk mencoba."
