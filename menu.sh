#!/bin/bash
# Menu Manager for ZiVPN
# AcilShop Premium Script (3 Columns Layout)

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
BLUE='\033[0;34m'
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

box_line() { echo -e "┌$(printf '%*s' "$(( $1 - 2 ))" | tr ' ' '─')┐"; }
box_sep()  { echo -e "├$(printf '%*s' "$(( $1 - 2 ))" | tr ' ' '─')┤"; }
box_end()  { echo -e "└$(printf '%*s' "$(( $1 - 2 ))" | tr ' ' '─')┘"; }

box_row() {
  local width="$1" text="$2"
  local max=$((width-4))
  # Hapus kode warna untuk hitung panjang string asli
  local clean_text=$(echo -e "$text" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g")
  local len=${#clean_text}
  
  if (( len > max )); then 
      # Kalau kepanjangan potong (logika sederhana)
      printf "│ %-${max}s │\n" "$clean_text"
  else
      # Print dengan padding sisa
      local gap=$((max - len))
      printf "│ %s%*s │\n" "$text" "$gap" ""
  fi
}

big_banner() {
  local width="$1"
  # ASCII Art ZivCil
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
  (( W < 74 )) && W=74 # Minimal lebar agar 3 kolom muat

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
  # Baris 1: Status Title
  box_row "$BW" "$(center_text "SERVER STATUS INFORMATION" $((BW-4)))"
  box_sep "$BW"
  # Baris 2: Info (Manual formatting for alignment)
  # Kita pakai printf manual di dalam box
  printf "│  %-20s : %-38s │\n" "Domain" "${GREEN}${DOMAIN}${NC}"
  printf "│  %-20s : %-38s │\n" "IP Server" "${YELLOW}${IP_SERVER}${NC}"
  printf "│  %-20s : %-38s │\n" "RAM Usage" "${CYAN}${ram_used} / ${ram_total}${NC}"
  printf "│  %-20s : %-38s │\n" "Total User" "${WHITE}${TOTAL} Users${NC}"
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
  
  # Cek duplikat
  if jq -e ".auth.config[] | select(. == \"$new_pass\")" "$CONFIG_FILE" > /dev/null 2>&1; then
    echo -e "${RED}[ERROR] Password/User sudah ada!${NC}"
    sleep 2
    return
  fi

  read -p "Masa Aktif (Hari)      : " masa_aktif
  if ! [[ "$masa_aktif" =~ ^[0-9]+$ ]]; then
      masa_aktif=30 # Default jika input salah
  fi

  # 1. Tambah ke Config JSON
  jq --arg pass "$new_pass" '.auth.config += [$pass]' "$CONFIG_FILE" > /tmp/config.tmp && mv /tmp/config.tmp "$CONFIG_FILE"

  # 2. Tambah ke Database User (Format: pass expired_date)
  # Tanggal Expired (YYYY-MM-DD)
  exp_date=$(date -d "+$masa_aktif days" +"%Y-%m-%d")
  echo "$new_pass $exp_date" >> "$USER_DB"

  # 3. Restart & Info
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
  
  # Generate Random Pass
  trial_pass="trial$(shuf -i 100-9999 -n 1)"
  
  # 1. Tambah ke Config JSON
  jq --arg pass "$trial_pass" '.auth.config += [$pass]' "$CONFIG_FILE" > /tmp/config.tmp && mv /tmp/config.tmp "$CONFIG_FILE"

  # 2. Tambah ke Database Trial (Format: pass timestamp)
  # Expired 60 Menit dari sekarang
  exp_time=$(date -d "+60 minutes" +%s)
  echo "$trial_pass $exp_time" >> "$TRIAL_DB"

  # 3. Restart
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
    # Hapus dari JSON
    jq --arg pass "$del_pass" '.auth.config -= [$pass]' "$CONFIG_FILE" > /tmp/config.tmp && mv /tmp/config.tmp "$CONFIG_FILE"
    
    # Hapus dari Database (User & Trial)
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
#  LAYOUT 3 KOLOM DINAMIS
# ==========================================
draw_menu_3col() {
  local W=$(term_cols)
  (( W < 74 )) && W=74

  local BW=$((W-4))
  local inner=$((BW-2)) # Lebar area dalam box
  local col_w=$((inner/3)) # Lebar per kolom

  box_line "$BW"
  box_row  "$BW" "$(center_text "MAIN MENU NAVIGATION" $((BW-4)))"
  box_sep  "$BW"

  # Format Printf untuk 3 kolom
  # Kita kurangi sedikit col_w untuk margin
  local txt_w=$((col_w - 2)) 
  local fmt="│ %-${txt_w}s %-${txt_w}s %-${txt_w}s │\n"

  # --- BARIS 1 ---
  # Col 1: Add User, Col 2: Trial, Col 3: Del User
  printf "$fmt" \
    "${GREEN}[1]${NC} Create User" \
    "${GREEN}[2]${NC} Create Trial" \
    "${GREEN}[3]${NC} Delete User"

  # --- BARIS 2 ---
  # Col 1: List User, Col 2: Clear RAM, Col 3: Restart
  printf "$fmt" \
    "${GREEN}[4]${NC} List User" \
    "${GREEN}[5]${NC} Clear Cache" \
    "${GREEN}[6]${NC} Restart VPN"

  box_sep "$BW"

  # --- BARIS 3 (EXIT & UNINSTALL) ---
  # Kita buat rata tengah untuk baris terakhir
  local half=$((inner/2))
  printf "│ %-${half}s %-${half}s │\n" \
    "     ${RED}[7] Uninstall Script${NC}" \
    "     ${YELLOW}[x] Exit Menu${NC}"

  box_end "$BW"
  echo
}

# ==========================================
#  MAIN LOOP
# ==========================================
while true; do
  show_header
  draw_menu_3col
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
      # Ganti link ini dengan link uninstall Anda jika ada
      echo "Fitur uninstall belum dikonfigurasi."
      sleep 2 ;;
    x|X) 
      clear
      exit 0 ;;
    *) 
      echo -e "${RED}Pilihan tidak valid!${NC}"
      sleep 1 ;;
  esac
done
