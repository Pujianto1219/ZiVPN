#!/bin/bash
# ==========================================
#  ZiVPN MANAGER - PREMIUM EDITION
#  Design Inspired by Console Style
# ==========================================

# --- CONFIG & DATABASE ---
CONFIG_FILE="/etc/zivpn/config.json"
DOMAIN_FILE="/etc/zivpn/domain"
USER_DB="/etc/zivpn/user.db"
TRIAL_DB="/etc/zivpn/trial.db"

# --- COLORS (SESUAI GAMBAR) ---
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
MYIP=$(curl -s ifconfig.me)

# --- HELPER FUNCTIONS ---
function pause() {
    echo -e ""
    read -n 1 -s -r -p "Press any key to continue..."
    menu
}

# --- HEADER FUNCTION (ASCII ART) ---
function show_header() {
    clear
    echo -e "${BLUE}"
    echo -e "  ☆ZIVPN☆"
    echo -e "  ███████╗██╗██╗   ██╗██████╗ ███╗   ██╗"
    echo -e "  ╚══███╔╝██║██║   ██║██╔══██╗████╗  ██║"
    echo -e "    ███╔╝ ██║██║   ██║██████╔╝██╔██╗ ██║"
    echo -e "   ███╔╝  ██║╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║"
    echo -e "  ███████╗██║ ╚████╔╝ ██║     ██║ ╚████║"
    echo -e "  ╚══════╝╚═╝  ╚═══╝  ╚═╝     ╚═╝  ╚═══╝"
    echo -e "${NC}"
    
    echo -e "      ${CYAN}ZiVPN MANAGER - v2.0 for AcilShop${NC}"
    echo -e "      ${GRAY}by: @AcilShop | Premium Script${NC}"
    echo -e "${YELLOW}===============================================${NC}"
    echo -e "${YELLOW}||      ACCOUNT MANAGEMENT PANEL </>         ||${NC}"
    echo -e "${YELLOW}===============================================${NC}"
    echo -e ""
    echo -e "  ${GREEN}●${NC} Public IP Address: ${PURPLE}< ${RED}$MYIP ${PURPLE}>${NC}"
    echo -e "  ${CYAN}<<< === === === === === === === === === >>>${NC}"
}

# --- MENU ACTIONS ---

function add_user() {
    echo -e "\n  ${GREEN}[+] ADD NEW ACCOUNT${NC}"
    read -p "  Username : " user
    
    # Cek user
    if grep -q "$user" "$CONFIG_FILE"; then
        echo -e "  ${RED}[!] Error: Username exists!${NC}"; pause
    fi
    
    read -p "  Duration (Days) : " masa_aktif
    [ -z "$masa_aktif" ] && masa_aktif=30
    
    # Logic Add (Config & DB)
    jq --arg u "$user" '.auth.config += [$u]' "$CONFIG_FILE" > /tmp/conf && mv /tmp/conf "$CONFIG_FILE"
    
    exp_date=$(date -d "+$masa_aktif days" +"%Y-%m-%d")
    echo "$user $exp_date" >> "$USER_DB"
    
    systemctl restart zivpn
    echo -e "  ${GREEN}[OK] User Created! Expired: $exp_date${NC}"; pause
}

function trial_user() {
    echo -e "\n  ${GREEN}[+] GENERATE TRIAL${NC}"
    user="trial$(shuf -i 1000-9999 -n 1)"
    
    jq --arg u "$user" '.auth.config += [$u]' "$CONFIG_FILE" > /tmp/conf && mv /tmp/conf "$CONFIG_FILE"
    
    # Expired 1 Jam
    exp_time=$(date -d "+60 minutes" +%s)
    echo "$user $exp_time" >> "$TRIAL_DB"
    
    systemctl restart zivpn
    echo -e "  ${GREEN}[OK] Trial: $user (60 Mins)${NC}"; pause
}

function list_user() {
    echo -e "\n  ${YELLOW}[#] LIST ACCOUNTS${NC}"
    echo -e "  -------------------------"
    jq -r '.auth.config[]' "$CONFIG_FILE" | nl -s ". "
    echo -e "  -------------------------"
    pause
}

function del_user() {
    echo -e "\n  ${RED}[-] DELETE ACCOUNT${NC}"
    read -p "  Input Username : " user
    
    if grep -q "$user" "$CONFIG_FILE"; then
        jq --arg u "$user" '.auth.config -= [$u]' "$CONFIG_FILE" > /tmp/conf && mv /tmp/conf "$CONFIG_FILE"
        sed -i "/^$user /d" "$USER_DB"
        sed -i "/^$user /d" "$TRIAL_DB"
        systemctl restart zivpn
        echo -e "  ${GREEN}[OK] User deleted.${NC}"
    else
        echo -e "  ${RED}[!] User not found.${NC}"
    fi
    pause
}

function vps_info() {
    echo -e "\n  ${CYAN}[i] VPS INFORMATION${NC}"
    echo -e "  -------------------------"
    echo -e "  Domain   : $DOMAIN"
    echo -e "  Ram Used : $(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2}')"
    echo -e "  Disk     : $(df -h / | awk 'NR==2{print $5}')"
    echo -e "  Uptime   : $(uptime -p)"
    echo -e "  -------------------------"
    pause
}

# --- MAIN MENU DISPLAY ---
function menu() {
    show_header
    # Mapping Menu sesuai gambar (Simbol disesuaikan)
    echo -e "  ${WHITE}[1]${NC} 👤 Add Account"
    echo -e "  ${WHITE}[2]${NC} 📄 List Account Details"
    echo -e "  ${WHITE}[3]${NC} 🗑️  Delete Account"
    echo -e "  ${WHITE}[4]${NC} ⏳ Create Trial Account ${GRAY}(1 Hour)${NC}"
    echo -e "  ${WHITE}[5]${NC} 🧹 Clear Cache RAM"
    echo -e "  ${WHITE}[6]${NC} 🔄 Restart Services"
    echo -e "  ${WHITE}[7]${NC} ⚙️  VPS Info & Status"
    echo -e "  ${CYAN}<<< ... ... ... ... ... ... ... ... ... >>>${NC}"
    echo -e "  ${RED}[8] ?  Uninstall Script${NC}"
    echo -e "  ${RED}[0]    Exit${NC}"
    echo -e ""
    read -p " //_> Choose an option: " opt
    
    case $opt in
        1) add_user ;;
        2) list_user ;;
        3) del_user ;;
        4) trial_user ;;
        5) 
           echo 3 > /proc/sys/vm/drop_caches
           echo -e "\n  ${GREEN}[OK] RAM Cache Cleared!${NC}"; pause ;;
        6) 
           systemctl restart zivpn
           echo -e "\n  ${GREEN}[OK] Service Restarted!${NC}"; pause ;;
        7) vps_info ;;
        8) 
           echo -e "\n  ${RED}[!] Running Uninstaller...${NC}"
           wget -q https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/uninstall.sh && chmod +x uninstall.sh && ./uninstall.sh
           exit ;;
        0) clear; exit ;;
        *) echo -e "\n  ${RED}[!] Invalid Option${NC}"; sleep 1; menu ;;
    esac
}

# Start Menu
menu
