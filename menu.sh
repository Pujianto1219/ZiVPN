#!/bin/bash
# Menu Manager for ZiVPN
# AcilShop Premium Script (Compact 3-Column Layout)

CONFIG_FILE="/etc/zivpn/config.json"
DOMAIN_FILE="/etc/zivpn/domain"
USER_DB="/etc/zivpn/user.db"
TRIAL_DB="/etc/zivpn/trial.db"

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
if ! command -v jq &> /dev/null; then
  apt-get install jq -y > /dev/null 2>&1
fi

# ===== UI Helpers =====
term_cols() { tput cols 2>/dev/null || echo 80; }

center_text() {
  local text="$1" width="$2"
  local len=${#text}
  if (( len >= width )); then
    echo "$text"
  else
    local pad=$(( (width - len) / 2 ))
    printf "%*s%s%*s" "$pad" "" "$text" $((width - len - pad)) ""
  fi
}

# Fungsi Garis Kotak
box_line() { echo -e "┌$(printf '%*s' "$(( $1 - 2 ))" | tr ' ' '─')┐"; }
box_sep()  { echo -e "├$(printf '%*s' "$(( $1 - 2 ))" | tr ' ' '─')┤"; }
box_end()  { echo -e "└$(printf '%*s' "$(( $1 - 2 ))" | tr ' ' '─')┘"; }

# Fungsi Baris Text dalam Kotak
box_row() {
  local width="$1" text="$2"
  local max=$((width-4))
  local clean_text=$(echo -e "$text" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g")
  local len=${#clean_text}
  
  if (( len > max )); then 
      printf "│ %-${max}s │\n" "$clean_text"
  else
      local gap=$((max - len))
      printf "│ %s%*s │\n" "$text" "$gap" ""
  fi
}

big_banner() {
  local width="$1"
  echo -e "${CYAN}"
  center_text "███████╗██╗██╗   ██╗ ██████╗██╗██╗      " "$width"
  center_text "╚══███╔╝██║██║   ██║██╔════╝██║██║      " "$width"
  center_text "  ███╔╝ ██║██║   ██║██║     ██║██║      " "$width"
  center_text " ███╔╝  ██║╚██╗ ██╔╝██║     ██║██║      " "$width"
  center_text "███████╗██║ ╚████╔╝ ╚██████╗██║███████╗" "$width"
  center_text "╚══════╝╚═╝  ╚═══╝   ╚═════╝╚═╝╚══════╝" "$width"
  echo -e "${NC}"
  echo -e "${YELLOW}$(center_text "PREMIUM VPN MANAGER by ACILSHOP" "$width")${NC}"
}

show_header() {
  clear
  local W=$(term_cols)
  (( W < 74 )) && W=74

  # Info System
  ram_used=$(free -m | awk 'NR==2{printf "%.2fGB", $3/1024}')
  ram_total=$(free -m | awk 'NR==2{printf "%.2fGB", $2/1024}')
  IP_SERVER=$(curl -s ifconfig.me)
  TOTAL=$(jq '.auth.config | length' "$CONFIG_FILE" 2>/dev/null || echo "0")

  echo
  big_banner "$W"
  echo
  
  local BW=$((W-4))
  box_line "$BW"
  box_row "$BW" "$(center_text "SERVER STATUS INFORMATION" $((BW-4)))"
  box_sep "$BW"
  printf "│  %-16s : %-42s │\n" "Domain" "${GREEN}${DOMAIN}${NC}"
  printf "│  %-16s : %-42s │\n" "IP Server" "${YELLOW}${IP_SERVER}${NC}"
  printf "│  %-16s : %-42s │\n" "RAM Usage" "${CYAN}${ram_used} / ${ram_total}${NC}"
  printf "│  %-16s : %-42s │\n" "Total User" "${WHITE}${TOTAL} Users${NC}"
  box_end "$BW"
  echo
}

pause_back() { read -n 1 -s -r -p "Tekan [ENTER] untuk kembali..."; }

# ==========================================
#  FUNCTION ADD USER (DENGAN EXPIRED)
# ==========================================
add_user() {
  echo -e "\n${YELLOW}=== BUAT USER BARU ===${NC}"
  
  read -p "Masukkan Password Baru : " new_pass
  if [ -z "$new_pass" ]; then echo "Password tidak boleh kosong!"; sleep 1; return; fi
  
  if jq -e ".auth.config[] | select(. == \"$new_pass\")" "$CONFIG_FILE" > /dev/null 2>&1; then
    echo -e "${RED}[ERROR] Password/User sudah ada!${NC}"
    sleep 2
    return
  fi

  read -p "Masa Aktif (Hari)      : " masa_aktif
  if ! [[ "$masa_aktif" =~ ^[0-9]+$ ]]; then
      masa_aktif=30 
  fi

  # Simpan ke Config
  jq --arg pass "$new_pass" '.auth.config += [$pass]' "$CONFIG_FILE" > /tmp/config.tmp && mv /tmp/config.tmp "$CONFIG_FILE"

  # Simpan ke Database (User)
  exp_date=$(date -d "+$masa_aktif days" +"%Y-%m-%d")
  echo "$new_pass $exp_date" >> "$USER_DB"

  systemctl restart zivpn
  
  clear
  echo -e "${GREEN}=================================${NC}"
  echo -e "${GREEN}      USER BERHASIL DIBUAT       ${NC}"
  echo -e "${GREEN}=================================${NC}"
  echo -e "Password   : ${YELLOW}$new_pass${NC}"
  echo -e "Expired    : ${CYAN}$exp_date${NC} ($masa_aktif Hari)"
  echo -e "IP/Host    : $IP_SERVER"
  echo -e "Domain     : $DOMAIN"
  echo -e "Port UDP   : 5667"
  echo -e "${GREEN}=================================${NC}"
  pause_back
}

# ==========================================
#  FUNCTION TRIAL USER (AUTO 60 MENIT)
# ==========================================
trial_user() {
  echo -e "\n${YELLOW}=== BUAT USER TRIAL ===${NC}"
  
  trial_pass="trial$(shuf -i 100-9999 -n 1)"
  
  jq --arg pass "$trial_pass" '.auth.config += [$pass]' "$CONFIG_FILE" > /tmp/config.tmp && mv /tmp/config.tmp "$CONFIG_FILE"

  # Simpan ke Database (Trial) - Expired 60 Menit
  exp_time=$(date -d "+60 minutes" +%s)
  echo "$trial_pass $exp_time" >> "$TRIAL_DB"

  systemctl restart zivpn

  clear
  echo -e "${CYAN}=================================${NC}"
  echo -e "${CYAN}      TRIAL BERHASIL DIBUAT      ${NC}"
  echo -e "${CYAN}=================================${NC}"
  echo -e "Password   : ${YELLOW}$trial_pass${NC}"
  echo -e "Limit Time : ${GREEN}60 Menit${NC}"
  echo -e "Domain     : $DOMAIN"
  echo -e "Port UDP   : 5667"
  echo -e "${CYAN}=================================${NC}"
  pause_back
}

del_user() {
  echo -e "\n${YELLOW}=== HAPUS USER ===${NC}"
  jq -r '.auth.config[]' "$CONFIG_FILE"
  echo ""
  read -p "Masukkan Password yg dihapus: " del_pass

  if jq -e ".auth.config[] | select(. == \"$del_pass\")" "$CONFIG_FILE" > /dev/null 2>&1; then
    jq --arg pass "$del_pass" '.auth.config -= [$pass]' "$CONFIG_FILE" > /tmp/config.tmp && mv /tmp/config.tmp "$CONFIG_FILE"
    
    # Bersihkan DB
    sed -i "/^$del_pass /d" "$USER_DB"
    sed -i "/^$del_pass /d" "$TRIAL_DB"

    systemctl restart zivpn
    echo -e "${GREEN}User '$del_pass' berhasil dihapus.${NC}"
  else
    echo -e "${RED}User tidak ditemukan.${NC}"
  fi
  pause_back
}

list_user() {
  echo -e "\n${YELLOW}=== LIST USER AKTIF ===${NC}"
  LEN=$(jq '.auth.config | length' "$CONFIG_FILE" 2>/dev/null || echo "0")
  if [ "$LEN" -eq 0 ]; then
    echo -e "${RED}(Database Kosong)${NC}"
  else
    echo -e "${CYAN}-------------------------------${NC}"
    jq -r '.auth.config[]' "$CONFIG_FILE"
    echo -e "${CYAN}-------------------------------${NC}"
  fi
  pause_back
}

clear_cache() {
  echo -e "\n${YELLOW}Membersihkan Cache RAM...${NC}"
  sync; echo 3 > /proc/sys/vm/drop_caches
  sleep 1
  echo -e "${GREEN}Cache berhasil dibersihkan!${NC}"
  pause_back
}

# ==========================================
#  LAYOUT 3 KOLOM RAPAT (COMPACT)
# ==========================================
draw_menu_compact() {
  local W=$(term_cols)
  (( W < 74 )) && W=74

  local BW=$((W-4))
  local inner=$((BW-2))
  local col_w=$((inner/3))

  box_line "$BW"
  box_row  "$BW" "$(center_text "MAIN MENU NAVIGATION" $((BW-4)))"
  box_sep  "$BW"

  # Format Printf (Lebar kolom dinamis)
  local txt_w=$((col_w - 2)) 
  local fmt="│ %-${txt_w}s %-${txt_w}s %-${txt_w}s │\n"

  # Baris 1: 1, 2, 3
  printf "$fmt" \
    "${GREEN}[1]${NC} Create User" \
    "${GREEN}[2]${NC} Create Trial" \
    "${GREEN}[3]${NC} Delete User"

  # Baris 2: 4, 5, 6
  printf "$fmt" \
    "${GREEN}[4]${NC} List User" \
    "${GREEN}[5]${NC} Clear Cache" \
    "${GREEN}[6]${NC} Restart VPN"

  # Baris 3: 7, x (Rapat, tanpa garis pemisah tambahan)
  printf "$fmt" \
    "${RED}[7]${NC} Uninstall" \
    "${YELLOW}[x]${NC} Exit Menu" \
    "" 

  box_end "$BW"
  echo
}

# ==========================================
#  MAIN LOOP
# ==========================================
while true; do
  show_header
  draw_menu_compact
  read -p " Select Option [1-x] : " opt
  case $opt in
    1) add_user ;;
    2) trial_user ;;
    3) del_user ;;
    4) list_user ;;
    5) clear_cache ;;
    6) 
       echo -e "\n${YELLOW}Restarting Services...${NC}"
       systemctl restart zivpn
       sleep 1
       echo -e "${GREEN}Done.${NC}"
       sleep 1
       ;;
    7)
      echo "Uninstalling..."
      # Link uninstall placeholder
      echo "Silakan update link uninstall di script."
      sleep 2 ;;
    x|X) 
      clear
      exit 0 ;;
    *) 
      echo -e "${RED}Pilihan tidak valid!${NC}"
      sleep 1 ;;
  esac
done
