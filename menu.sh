#!/bin/bash

# --- Warna ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# --- Fungsi Header ---
show_header() {
    clear
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${YELLOW}           ZiVPN MAIN MENU              ${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${WHITE} OS        : $(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/PRETTY_NAME//g' | sed 's/=//g' | sed 's/"//g')${NC}"
    echo -e "${WHITE} IP Server : $(curl -s ifconfig.me)${NC}"
    echo -e "${CYAN}=========================================${NC}"
}

# --- Loop Menu ---
while true; do
    show_header
    echo -e "${GREEN}[1]${NC} Install/Update Konfigurasi VPN"
    echo -e "${GREEN}[2]${NC} Cek Status Service"
    echo -e "${GREEN}[3]${NC} Tambah User (Contoh)"
    echo -e "${GREEN}[4]${NC} Reboot Server"
    echo -e "${GREEN}[5]${NC} Exit"
    echo -e "${CYAN}=========================================${NC}"
    read -p "Pilih menu [1-5]: " option

    case $option in
        1)
            echo -e "\n${YELLOW}Memproses Install/Update...${NC}"
            # Masukkan perintah instalasi resource kamu di sini
            # Contoh: wget ...
            sleep 2
            ;;
        2)
            echo -e "\n${YELLOW}Status Service:${NC}"
            # Contoh cek service (sesuaikan dengan service vpn kamu)
            # systemctl status ssh | grep Active
            echo "Service running (Dummy Status)..."
            read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali..."
            ;;
        3)
            echo -e "\n${YELLOW}Fitur Tambah User${NC}"
            # Script tambah user disini
            read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali..."
            ;;
        4)
            echo -e "\n${RED}Rebooting...${NC}"
            reboot
            ;;
        5)
            clear
            echo -e "Terima kasih telah menggunakan ZiVPN."
            exit 0
            ;;
        *)
            echo -e "\n${RED}Pilihan tidak valid!${NC}"
            sleep 1
            ;;
    esac
done
