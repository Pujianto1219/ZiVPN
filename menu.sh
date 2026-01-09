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
    echo -e "${GREEN}[1]${NC} Create User Account"
    echo -e "${GREEN}[2]${NC} Create Trial Account (24 Jam)"
    echo -e "${GREEN}[3]${NC} Hapus User"
    echo -e "${GREEN}[4]${NC} Cek Status Service"
    echo -e "${GREEN}[5]${NC} Uninstall ZiVPN"
    echo -e "${GREEN}[x]${NC} Exit"
    echo -e "${CYAN}=========================================${NC}"
    read -p "Pilih menu : " option

    case $option in
        1)
            echo -e "\n${YELLOW}=== BUAT AKUN BARU ===${NC}"
            read -p "Username   : " username
            read -p "Password   : " password
            read -p "Masa Aktif (hari): " masaaktif
            
            # Menghitung tanggal expired (Opsional, jika script butuh tanggal)
            exp_date=$(date -d "+${masaaktif} days" +"%Y-%m-%d")

            echo -e "${YELLOW}Membuat akun...${NC}"
            
            # ==========================================================
            # [PENTING] MASUKKAN COMMAND ZIVPN DISINI
            # Contoh logika: 
            # /usr/local/bin/zivpn adduser "$username" "$password" --exp "$masaaktif"
            # atau echo "$username $password" >> /etc/zivpn/passwd
            # ==========================================================
            
            sleep 2
            echo -e "${GREEN}Sukses! Akun $username telah dibuat.${NC}"
            echo -e "Expired pada: $exp_date"
            read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali..."
            ;;
        
        2)
            echo -e "\n${YELLOW}=== BUAT AKUN TRIAL ===${NC}"
            # Generate username random untuk trial
            user_trial="trial$(shuf -i 1000-9999 -n 1)"
            pass_trial="1"
            masaaktif="1" # 1 Hari

            echo -e "${YELLOW}Membuat akun trial...${NC}"

            # ==========================================================
            # [PENTING] MASUKKAN COMMAND ZIVPN DISINI
            # Gunakan variabel $user_trial dan $pass_trial
            # Contoh: 
            # /usr/local/bin/zivpn adduser "$user_trial" "$pass_trial" --exp "24h"
            # ==========================================================

            sleep 2
            clear
            echo -e "${CYAN}=================================${NC}"
            echo -e "${GREEN}    TRIAL ACCOUNT SUCCESS        ${NC}"
            echo -e "${CYAN}=================================${NC}"
            echo -e "Username : ${WHITE}$user_trial${NC}"
            echo -e "Password : ${WHITE}$pass_trial${NC}"
            echo -e "Expired  : ${WHITE}24 Jam${NC}"
            echo -e "${CYAN}=================================${NC}"
            read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali..."
            ;;

        3)
            echo -e "\n${YELLOW}=== HAPUS USER ===${NC}"
            read -p "Masukkan Username: " deluser
            
            # ==========================================================
            # MASUKKAN COMMAND HAPUS USER DISINI
            # Contoh: /usr/local/bin/zivpn deluser "$deluser"
            # ==========================================================
            
            echo -e "${GREEN}User $deluser berhasil dihapus.${NC}"
            sleep 2
            ;;

        4)
            echo -e "\n${YELLOW}Status Service:${NC}"
            if pgrep "zivpn" >/dev/null; then
                echo -e "${GREEN}ZiVPN Service is RUNNING${NC}"
            else
                echo -e "${RED}ZiVPN Service is STOPPED${NC}"
            fi
            read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali..."
            ;;
        
        5)
            # Link ke script uninstall one-liner
            echo -e "\n${RED}Menjalankan Uninstaller...${NC}"
            wget -O ziun.sh https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/uninstall.sh && chmod +x ziun.sh && ./ziun.sh
            exit 0
            ;;

        x)
            clear
            echo -e "Terima kasih."
            exit 0
            ;;
        *)
            echo -e "\n${RED}Pilihan tidak valid!${NC}"
            sleep 1
            ;;
    esac
done
