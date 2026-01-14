#!/bin/bash
# ==========================================
#  ZiVPN MANAGER - COMPACT V6
#  Manual Trial Duration & Tidier Grid
# ==========================================

# --- CONFIG & DATABASE ---
CONFIG_FILE="/etc/zivpn/config.json"
DOMAIN_FILE="/etc/zivpn/domain"
USER_DB="/etc/zivpn/user.db"
TRIAL_DB="/etc/zivpn/trial.db"
BOT_CONFIG="/etc/zivpn/bot.json"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
GRAY='\033[1;30m'

# --- LOAD DATA ---
if [ -f "$DOMAIN_FILE" ]; then
  DOMAIN=$(cat "$DOMAIN_FILE")
else
  DOMAIN="Unknown"
fi

# Cek IP & ISP (Cache)
if [ ! -f /tmp/ip_cache ]; then
    curl -s ipinfo.io/ip > /tmp/ip_cache
    curl -s ipinfo.io/org > /tmp/isp_cache
fi
MYIP=$(cat /tmp/ip_cache)
ISP=$(cat /tmp/isp_cache | cut -d " " -f 2-10)

# --- HELPER FUNCTIONS ---
function pause() {
    echo -e ""
    read -n 1 -s -r -p "Tekan [ENTER] untuk kembali..."
    menu
}

# --- HEADER FUNCTION ---
function show_header() {
    clear
    ram_used=$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2}')
    ram_total=$(free -m | awk 'NR==2{printf "%.1fGB", $2/1024}')
    disk_used=$(df -h / | awk 'NR==2{print $5}')
    cpu_load=$(top -bn1 | grep load | awk '{printf "%.2f", $(NF-2)}')
    
    echo -e "${CYAN}"
    echo -e " ███████╗██╗██╗   ██╗ ██████╗██╗██╗     "
    echo -e " ╚══███╔╝██║██║   ██║██╔════╝██║██║     "
    echo -e "   ███╔╝ ██║██║   ██║██║     ██║██║     "
    echo -e "  ███╔╝  ██║╚██╗ ██╔╝██║     ██║██║     "
    echo -e " ███████╗██║ ╚████╔╝ ╚██████╗██║███████╗"
    echo -e " ╚══════╝╚═╝  ╚═══╝   ╚═════╝╚═╝╚══════╝"
    echo -e "${NC}"
    echo -e "      ${YELLOW}PREMIUM MANAGER BY ACILSHOP${NC}"
    echo -e "${GRAY}================================================${NC}"
    
    printf "  %-18s : %-20s\n" "IP Server" "${GREEN}$MYIP${NC}"
    printf "  %-18s : %-20s\n" "Domain" "${CYAN}$DOMAIN${NC}"
    printf "  %-18s : %-20s\n" "ISP Name" "${PURPLE}$ISP${NC}"
    echo -e "${GRAY}  --------------------------------------------${NC}"
    printf "  %-18s : %-20s\n" "RAM Usage" "${YELLOW}$ram_used / $ram_total${NC}"
    printf "  %-18s : %-20s\n" "CPU Load" "${YELLOW}$cpu_load${NC}"
    printf "  %-18s : %-20s\n" "Disk Usage" "${YELLOW}$disk_used${NC}"
    echo -e "${GRAY}================================================${NC}"
}

# --- MAIN ACTIONS ---

function add_user() {
    echo -e "\n  ${GREEN}[+] ADD USER${NC}"
    read -p "  Username : " user
    grep -q "$user" "$CONFIG_FILE" && { echo -e "  ${RED}[!] Exists!${NC}"; pause; }
    
    read -p "  Durasi (Hari) : " masa_aktif
    [ -z "$masa_aktif" ] && masa_aktif=30
    
    jq --arg u "$user" '.auth.config += [$u]' "$CONFIG_FILE" > /tmp/conf && mv /tmp/conf "$CONFIG_FILE"
    
    exp_date=$(date -d "+$masa_aktif days" +"%Y-%m-%d")
    echo "$user $exp_date" >> "$USER_DB"
    systemctl restart zivpn
    echo -e "  ${GREEN}[OK] Created: $user ($masa_aktif Hari)${NC}"; pause
}

function trial_user() {
    echo -e "\n  ${GREEN}[+] TRIAL USER${NC}"
    user="trial$(shuf -i 100-9999 -n 1)"
    
    # [MODIFIKASI] Input Manual Menit
    read -p "  Durasi (Menit) [Default 60]: " masa_aktif
    
    # Validasi input harus angka, jika kosong/salah set ke 60
    if [[ -z "$masa_aktif" ]] || ! [[ "$masa_aktif" =~ ^[0-9]+$ ]]; then
        masa_aktif=60
    fi
    
    jq --arg u "$user" '.auth.config += [$u]' "$CONFIG_FILE" > /tmp/conf && mv /tmp/conf "$CONFIG_FILE"
    
    # Hitung expired berdasarkan menit
    exp_time=$(date -d "+$masa_aktif minutes" +%s)
    echo "$user $exp_time" >> "$TRIAL_DB"
    
    systemctl restart zivpn
    echo -e "  ${GREEN}[OK] Trial: $user ($masa_aktif Menit)${NC}"; pause
}

function del_user() {
    echo -e "\n  ${RED}[-] DELETE USER${NC}"
    read -p "  Username : " user
    if grep -q "$user" "$CONFIG_FILE"; then
        jq --arg u "$user" '.auth.config -= [$u]' "$CONFIG_FILE" > /tmp/conf && mv /tmp/conf "$CONFIG_FILE"
        sed -i "/^$user /d" "$USER_DB"
        sed -i "/^$user /d" "$TRIAL_DB"
        systemctl restart zivpn
        echo -e "  ${GREEN}[OK] Deleted.${NC}"
    else
        echo -e "  ${RED}[!] Not found.${NC}"
    fi
    pause
}

function list_user() {
    echo -e "\n  ${YELLOW}[#] USER LIST${NC}"
    jq -r '.auth.config[]' "$CONFIG_FILE" | nl
    pause
}

# --- BOT MANAGEMENT SUB-MENU ---

function install_bot() {
    echo -e "\n  ${CYAN}[*] INSTALL / REGISTER BOT${NC}"
    echo -e "  ${GRAY}Pastikan Anda sudah punya Bot Token dari @BotFather${NC}"
    echo ""
    read -p "  Input Bot Token : " bot_token
    read -p "  Input Admin ID  : " admin_id
    
    if [ -z "$bot_token" ] || [ -z "$admin_id" ]; then
        echo -e "  ${RED}[!] Data tidak boleh kosong!${NC}"; sleep 2; bot_menu
    fi

    echo -e "  ${YELLOW}Downloading Bot Script...${NC}"
    wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/bot.py -O /usr/bin/bot.py
    chmod +x /usr/bin/bot.py
    
    cat <<EOF > $BOT_CONFIG
{
  "bot_token": "$bot_token",
  "admin_id": "$admin_id"
}
EOF

    cat <<EOF > /etc/systemd/system/zivpn-bot.service
[Unit]
Description=ZiVPN Telegram Bot
After=network.target

[Service]
User=root
WorkingDirectory=/usr/bin
ExecStart=/usr/bin/python3 bot.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable zivpn-bot > /dev/null 2>&1
    systemctl start zivpn-bot > /dev/null 2>&1
    
    echo -e "  ${GREEN}[OK] Bot Berhasil Diaktifkan!${NC}"
    sleep 2
    bot_menu
}

function restart_bot() {
    echo -e "\n  ${YELLOW}[*] Restarting Bot Service...${NC}"
    systemctl restart zivpn-bot
    sleep 1
    echo -e "  ${GREEN}[OK] Done.${NC}"
    sleep 1
    bot_menu
}

function delete_bot() {
    echo -e "\n  ${RED}[!] DELETE BOT${NC}"
    read -p "  Yakin ingin menghapus bot? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        systemctl stop zivpn-bot
        systemctl disable zivpn-bot
        rm -f /etc/systemd/system/zivpn-bot.service
        rm -f /usr/bin/bot.py
        rm -f $BOT_CONFIG
        systemctl daemon-reload
        echo -e "  ${GREEN}[OK] Bot berhasil dihapus.${NC}"
    else
        echo -e "  ${YELLOW}Batal.${NC}"
    fi
    sleep 2
    bot_menu
}

function bot_menu() {
    clear
    echo -e "${CYAN}"
    echo -e "     TELEGRAM BOT MANAGER"
    echo -e "${GRAY}================================================${NC}"
    
    if systemctl is-active --quiet zivpn-bot; then
        echo -e "  STATUS BOT: ${GREEN}RUNNING [ON]${NC}"
    else
        echo -e "  STATUS BOT: ${RED}STOPPED [OFF]${NC}"
    fi
    echo -e "${GRAY}================================================${NC}"
    
    echo -e "  ${GREEN}[1]${NC} Register / Change Bot"
    echo -e "  ${GREEN}[2]${NC} Restart Bot Service"
    echo -e "  ${RED}[3]${NC} Stop & Delete Bot"
    echo -e "  ${YELLOW}[0]${NC} Back to Main Menu"
    echo -e "${GRAY}================================================${NC}"
    
    read -p "  Select Option [1-0]: " opt
    case $opt in
        1) install_bot ;;
        2) restart_bot ;;
        3) delete_bot ;;
        0) menu ;;
        *) echo -e "  ${RED}[!] Invalid!${NC}"; sleep 1; bot_menu ;;
    esac
}

# --- MAIN MENU DISPLAY ---
function menu() {
    show_header
    
    # [MODIFIKASI] TAMPILAN LEBIH RAPAT & SEJAJAR
    # Menggunakan printf agar kolom lurus sempurna
    
    printf "  ${GREEN}[1]${NC} %-23s ${GREEN}[2]${NC} %-23s\n" "Add User" "Trial Account"
    printf "  ${GREEN}[3]${NC} %-23s ${GREEN}[4]${NC} %-23s\n" "Delete User" "List User"
    printf "  ${CYAN}[5]${NC} %-23s ${CYAN}[6]${NC} %-23s\n" "Clear Cache" "Restart VPN"
    printf "  ${PURPLE}[7]${NC} %-23s ${PURPLE}[8]${NC} %-23s\n" "Bot Manager" "Update Script"
    printf "  ${RED}[9]${NC} %-23s ${RED}[0]${NC} %-23s\n" "Uninstall" "Exit"
    
    echo -e "${GRAY}================================================${NC}"
    read -p "  Select Menu [1-0]: " opt
    
    case $opt in
        1) add_user ;;
        2) trial_user ;;
        3) del_user ;;
        4) list_user ;;
        5) echo 3 > /proc/sys/vm/drop_caches; echo -e "\n  ${GREEN}[OK] RAM Clean.${NC}"; pause ;;
        6) systemctl restart zivpn; echo -e "\n  ${GREEN}[OK] Restarted.${NC}"; pause ;;
        7) bot_menu ;;
        8) wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/update.sh && chmod +x update.sh && ./update.sh; exit ;;
        9) wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/uninstall.sh && chmod +x uninstall.sh && ./uninstall.sh; exit ;;
        0) clear; exit ;;
        *) echo -e "\n  ${RED}[!] Invalid Option${NC}"; sleep 1; menu ;;
    esac
}

# Start
menu
