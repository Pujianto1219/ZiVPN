#!/bin/bash
# ==========================================
#  ZIVPN UNINSTALLER (CLEAN ALL)
#  Removes Menu, XP Scripts, Cronjob & DB
# ==========================================

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}        UNINSTALLING ZIVPN & CLEANING UP...     ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Mohon tunggu, sedang menghapus file..."
sleep 2

# 1. STOP & DISABLE SERVICE
echo -e "${YELLOW}[1/6] Menghentikan Service VPN...${NC}"
systemctl stop zivpn.service > /dev/null 2>&1
systemctl disable zivpn.service > /dev/null 2>&1

# 2. HAPUS SYSTEMD SERVICE
rm -f /etc/systemd/system/zivpn.service
systemctl daemon-reload

# 3. HAPUS CORE BINARY & CONFIG (DATABASE)
echo -e "${YELLOW}[2/6] Menghapus Konfigurasi & Database...${NC}"
# Hapus Binary
rm -f /usr/local/bin/zivpn
# Hapus Folder Config (Termasuk user.db, trial.db, cert, domain)
rm -rf /etc/zivpn 

# 4. HAPUS SCRIPT MENU & XP (SESUAIKAN DENGAN UPDATE TERBARU)
echo -e "${YELLOW}[3/6] Menghapus Menu & Script Helper...${NC}"
rm -f /usr/bin/menu
rm -f /usr/bin/xp-trial
rm -f /usr/bin/xp-user
rm -f /usr/bin/xp       # Jaga-jaga jika ada versi lama
rm -f /usr/bin/zivpn    # Jaga-jaga jika ada symlink

# 5. HAPUS CRONJOB (PENJADWAL)
echo -e "${YELLOW}[4/6] Membersihkan Cronjob (Auto Delete)...${NC}"
rm -f /etc/cron.d/xp_trial
rm -f /etc/cron.d/xp_user
rm -f /etc/cron.d/xp
rm -f /etc/cron.d/auto_reboot
service cron restart > /dev/null 2>&1

# 6. HAPUS SWAP RAM (KEMBALIKAN SPACE SSD)
# Cek apakah swapfile dari script ini ada
if [ -f /swapfile ]; then
    echo -e "${YELLOW}[5/6] Menghapus Swap RAM...${NC}"
    # Matikan swap
    swapoff /swapfile > /dev/null 2>&1
    # Hapus baris swap di fstab agar tidak error saat reboot
    sed -i '/swapfile/d' /etc/fstab
    # Hapus file fisik
    rm -f /swapfile
else
    echo -e "${GREEN}[INFO] Swap tidak ditemukan, melewati...${NC}"
fi

# 7. BERSIHKAN FIREWALL (IPTABLES)
# Opsional: Hanya menghapus rule redirect port 5667
iptables-save | grep -v "5667" | iptables-restore
netfilter-persistent save > /dev/null 2>&1

# 8. CEK STATUS AKHIR
echo -e "${YELLOW}[6/6] Verifikasi Penghapusan...${NC}"
if pgrep "zivpn" >/dev/null; then
  echo -e "${RED}[ERROR] Gagal menghentikan proses ZIVPN!${NC}"
  pkill zivpn
else
  echo -e "${GREEN}[OK] Proses ZIVPN berhenti.${NC}"
fi

if [ -d "/etc/zivpn" ]; then
  echo -e "${RED}[ERROR] Folder config masih ada!${NC}"
  rm -rf /etc/zivpn
else
  echo -e "${GREEN}[OK] Folder config bersih.${NC}"
fi

# 9. BERSIHKAN CACHE
echo 3 > /proc/sys/vm/drop_caches

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}      UNINSTALL SUKSES! BERSIH TOTAL.           ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Terima kasih telah menggunakan script AcilShop."
echo -e ""

# Hapus file uninstaller ini sendiri (Self Destruct)
rm -f uninstall.sh
rm -f ziun.sh
