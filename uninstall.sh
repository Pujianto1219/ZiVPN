#!/bin/bash
# - ZiVPN Remover & Menu Cleaner -

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

clear
echo -e "${YELLOW}Uninstalling ZiVPN & Cleaning Menu...${NC}"

# 1. Stop & Disable Services (Sesuai script asli kamu)
systemctl stop zivpn.service 1> /dev/null 2> /dev/null
systemctl stop zivpn_backfill.service 1> /dev/null 2> /dev/null
systemctl disable zivpn.service 1> /dev/null 2> /dev/null
systemctl disable zivpn_backfill.service 1> /dev/null 2> /dev/null

# 2. Hapus Service Files
rm /etc/systemd/system/zivpn.service 1> /dev/null 2> /dev/null
rm /etc/systemd/system/zivpn_backfill.service 1> /dev/null 2> /dev/null

# 3. Matikan Proses
killall zivpn 1> /dev/null 2> /dev/null

# 4. Hapus File Utama & Config
rm -rf /etc/zivpn 1> /dev/null 2> /dev/null
rm /usr/local/bin/zivpn 1> /dev/null 2> /dev/null

# 5. HAPUS MENU (Tambahan agar menu hilang)
echo -e "${YELLOW}Removing Menu Shortcut...${NC}"
rm -f /usr/bin/menu 1> /dev/null 2> /dev/null

# 6. Cek Status Proses
if pgrep "zivpn" >/dev/null; then
  echo -e "${RED}Server Running (Gagal Stop)${NC}"
else
  echo -e "${GREEN}Server Stopped${NC}"
fi

# 7. Cek Sisa File
file="/usr/local/bin/zivpn"
if [ -e "$file" ]; then
  echo -e "${RED}Files still remaining, try again${NC}"
else
  echo -e "${GREEN}Successfully Removed${NC}"
fi

# 8. Bersihkan Cache & Swap (Sesuai script asli kamu)
echo -e "${YELLOW}Cleaning Cache & Swap...${NC}"
echo 3 > /proc/sys/vm/drop_caches
sysctl -w vm.drop_caches=3 1> /dev/null 2> /dev/null
swapoff -a && swapon -a

echo -e "${GREEN}Done.${NC}"

# 9. Hapus File Uninstaller Ini Sendiri (Self-Destruct)
rm -f ziun.sh
