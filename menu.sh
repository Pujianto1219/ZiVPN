#!/bin/bash

# Config Path
CONFIG_FILE="/etc/zivpn/config.json"

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# Cek Dependency jq
if ! command -v jq &> /dev/null; then
    echo "Install jq dulu..."
    apt-get install jq -y
fi

show_header() {
    clear
    echo -e "${CYAN}============================================${NC}"
    echo -e "${YELLOW}           ZiVPN MANAGER (JSON MODE)       ${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo -e "${WHITE} IP Server : ${YELLOW}$(curl -s ifconfig.me)${NC}"
    # Hitung jumlah item dalam array "config"
    TOTAL_USER=$(jq '.auth.config | length' $CONFIG_FILE)
    echo -e "${WHITE} Total User: ${YELLOW}$TOTAL_USER${NC}"
    echo -e "${CYAN}============================================${NC}"
}

add_user() {
    echo -e "\n${YELLOW}=== TAMBAH PASSWORD/USER ===${NC}"
    read -p "Masukkan Password Baru : " new_pass

    # Cek apakah password sudah ada di array
    if jq -e ".auth.config[] | select(. == \"$new_pass\")" $CONFIG_FILE > /dev/null; then
        echo -e "${RED}Error: Password '$new_pass' sudah ada!${NC}"
    else
        # Tambahkan password ke array JSON
        jq --arg pass "$new_pass" '.auth.config += [$pass]' $CONFIG_FILE > /tmp/config.tmp && mv /tmp/config.tmp $CONFIG_FILE
        
        systemctl restart zivpn
        echo -e "${GREEN}Sukses menambah user: $new_pass${NC}"
    fi
    read -n 1 -s -r -p "Tekan tombol untuk kembali..."
}

trial_user() {
    echo -e "\n${YELLOW}=== BUAT AKUN TRIAL ===${NC}"
    # Buat random string
    trial_pass="trial$(shuf -i 1000-9999 -n 1)"
    
    # Tambahkan ke JSON
    jq --arg pass "$trial_pass" '.auth.config += [$pass]' $CONFIG_FILE > /tmp/config.tmp && mv /tmp/config.tmp $CONFIG_FILE
    
    systemctl restart zivpn
    
    # (Opsional) Karena sistem JSON ZiVPN tidak menyimpan tanggal expired, 
    # trial ini hanya menambah password. Penghapusan harus manual atau pakai cronjob lain.
    
    clear
    echo -e "${CYAN}=================================${NC}"
    echo -e "${GREEN}    TRIAL GENERATED              ${NC}"
    echo -e "${CYAN}=================================${NC}"
    echo -e "Password : ${WHITE}$trial_pass${NC}"
    echo -e "Port UDP : ${WHITE}6000-19999${NC}"
    echo -e "${CYAN}=================================${NC}"
    read -n 1 -s -r -p "Tekan tombol untuk kembali..."
}

del_user() {
    echo -e "\n${YELLOW}=== HAPUS PASSWORD/USER ===${NC}"
    # Tampilkan list dulu
    echo "Daftar User saat ini:"
    jq -r '.auth.config[]' $CONFIG_FILE
    echo ""
    read -p "Masukkan Password yang ingin dihapus: " del_pass

    if jq -e ".auth.config[] | select(. == \"$del_pass\")" $CONFIG_FILE > /dev/null; then
        # Hapus item dari array
        jq --arg pass "$del_pass" '.auth.config -= [$pass]' $CONFIG_FILE > /tmp/config.tmp && mv /tmp/config.tmp $CONFIG_FILE
        
        systemctl restart zivpn
        echo -e "${GREEN}Password '$del_pass' berhasil dihapus.${NC}"
    else
        echo -e "${RED}Password tidak ditemukan!${NC}"
    fi
    read -n 1 -s -r -p "Tekan tombol untuk kembali..."
}

list_user() {
    echo -e "\n${YELLOW}=== LIST USER (CONFIG.JSON) ===${NC}"
    jq -r '.auth.config[]' $CONFIG_FILE
    echo -e "-------------------------------"
    read -n 1 -s -r -p "Tekan tombol untuk kembali..."
}

# --- MENU LOOP ---
while true; do
    show_header
    echo -e "${GREEN}[1]${NC} Tambah User"
    echo -e "${GREEN}[2]${NC} Trial User"
    echo -e "${GREEN}[3]${NC} Hapus User"
    echo -e "${GREEN}[4]${NC} Lihat List User"
    echo -e "${GREEN}[5]${NC} Restart Service"
    echo -e "${GREEN}[6]${NC} Uninstall"
    echo -e "${GREEN}[x]${NC} Exit"
    echo -e "${CYAN}============================================${NC}"
    read -p "Pilih Menu [1-x]: " option

    case $option in
        1) add_user ;;
        2) trial_user ;;
        3) del_user ;;
        4) list_user ;;
        5) 
           echo "Restarting..."
           systemctl restart zivpn
           echo "Done."
           sleep 1
           ;;
        6)
           echo -e "\n${RED}Menjalankan Uninstaller...${NC}"
           wget -q -O ziun.sh https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/uninstall.sh
           chmod +x ziun.sh
           ./ziun.sh
           exit 0
           ;;
        x) clear; exit 0 ;;
        *) echo "Pilihan salah"; sleep 1 ;;
    esac
done
