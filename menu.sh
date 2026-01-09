#!/bin/bash
# Menu Manager for ZiVPN
# AcilShop Premium Script

CONFIG_FILE="/etc/zivpn/config.json"
DOMAIN_FILE="/etc/zivpn/domain"

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# Load Domain
if [ -f "$DOMAIN_FILE" ]; then
    DOMAIN=$(cat "$DOMAIN_FILE")
else
    DOMAIN=$(curl -s ifconfig.me)
fi

# Cek JQ
if ! command -v jq &> /dev/null; then apt-get install jq -y > /dev/null 2>&1; fi

show_header() {
    clear
    # Hitung RAM
    ram_total=$(free -m | awk 'NR==2{printf "%.2fGB", $2/1024}')
    ram_used=$(free -m | awk 'NR==2{printf "%.2fGB", $3/1024}')
    
    echo -e "${CYAN}============================================${NC}"
    echo -e "${YELLOW}           ZiVPN SERVER MANAGER            ${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo -e "${WHITE} Domain    : ${GREEN}$DOMAIN${NC}"
    echo -e "${WHITE} IP Server : ${YELLOW}$(curl -s ifconfig.me)${NC}"
    echo -e "${WHITE} RAM Usage : ${CYAN}$ram_used / $ram_total${NC}"
    
    # Hitung total user
    TOTAL=$(jq '.auth.config | length' $CONFIG_FILE 2>/dev/null || echo "0")
    echo -e "${WHITE} Total User: ${YELLOW}$TOTAL${NC}"
    
    echo -e "${CYAN}============================================${NC}"
    echo -e "${YELLOW}         POWERED BY ACILSHOP               ${NC}"
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
    echo -e "Domain : $DOMAIN"
    echo -e "Port   : 5667"
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

clear_cache() {
    echo -e "\n${YELLOW}Membersihkan Cache RAM...${NC}"
    sync; echo 3 > /proc/sys/vm/drop_caches
    sleep 1
    echo -e "${GREEN}Cache berhasil dibersihkan!${NC}"
    read -n 1 -s -r -p "Tekan tombol untuk kembali..."
}

list_user() {
    echo -e "\n${YELLOW}=== LIST USER ===${NC}"
    LEN=$(jq '.auth.config | length' $CONFIG_FILE)
    if [ "$LEN" -eq 0 ]; then 
        echo -e "${RED}(Belum ada user)${NC}"
    else 
        jq -r '.auth.config[]' $CONFIG_FILE
    fi
    echo -e "-------------------------------"
    read -n 1 -s -r -p "Kembali..."
}

while true; do
    show_header
    echo -e "[1] Tambah User"
    echo -e "[2] Trial User"
    echo -e "[3] Hapus User"
    echo -e "[4] Lihat User"
    echo -e "[5] Bersihkan Cache RAM"
    echo -e "[6] Restart Service"
    echo -e "[7] Uninstall"
    echo -e "[x] Exit"
    read -p "Pilih: " opt
    case $opt in
        1) add_user ;;
        2) trial_user ;;
        3) del_user ;;
        4) list_user ;;
        5) clear_cache ;;
        6) systemctl restart zivpn; echo "Done."; sleep 1 ;;
        7) 
           echo "Uninstalling..."
           wget -q -O ziun.sh https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/uninstall.sh
           chmod +x ziun.sh && ./ziun.sh
           exit 0 ;;
        x) exit 0 ;;
        *) echo "Salah pilih"; sleep 1 ;;
    esac
done
