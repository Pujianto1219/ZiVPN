#!/usr/bin/env bash
set -euo pipefail

CFG="/etc/zivpn/config.json"
BKDIR="/etc/zivpn/backups"
EXPDB="/etc/zivpn/auth/expiry.db"   # password|YYYY-MM-DD

RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[0;33m"; CYAN="\033[0;36m"; NC="\033[0m"

require_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo -e "${RED}Run as root.${NC}"; exit 1; }; }
pause(){ read -r -p "Enter untuk lanjut..." _; }

need_jq() { command -v jq >/dev/null 2>&1 || { echo -e "${RED}jq not found. Install it first.${NC}"; exit 1; }; }
ensure_paths(){ mkdir -p "$BKDIR" "$(dirname "$EXPDB")"; touch "$EXPDB"; [[ -f "$CFG" ]] || { echo -e "${RED}Missing:${NC} $CFG"; exit 1; }; }

backup_cfg() {
  ts="$(date +"%Y%m%d-%H%M%S")"
  cp -a "$CFG" "${BKDIR}/config.json.${ts}.bak" 2>/dev/null || true
  ls -1t "${BKDIR}/config.json."*.bak 2>/dev/null | tail -n +31 | xargs -r rm -f
}

today_iso(){ date +"%Y-%m-%d"; }
calc_plus_days(){ local d="$1"; date -d "now +${d} days" +"%Y-%m-%d" 2>/dev/null || date -I -d "+${d} days" 2>/dev/null || date +"%Y-%m-%d"; }
is_expired(){ local exp="$1"; [[ -n "$exp" && "$(today_iso)" > "$exp" ]]; }

pw_in_cfg() {
  local pw="$1"
  jq -e --arg pw "$pw" '(.auth.config // []) | index($pw) != null' "$CFG" >/dev/null 2>&1
}

add_pw_to_cfg() {
  local pw="$1"
  backup_cfg
  tmp="$(mktemp)"
  jq --arg pw "$pw" '
    .auth.mode="passwords"
    | .auth.config = (((.auth.config // []) + [$pw]) | unique)
  ' "$CFG" >"$tmp"
  mv "$tmp" "$CFG"
}

remove_pw_from_cfg() {
  local pw="$1"
  backup_cfg
  tmp="$(mktemp)"
  jq --arg pw "$pw" '
    .auth.config = ((.auth.config // []) | map(select(. != $pw)))
  ' "$CFG" >"$tmp"
  mv "$tmp" "$CFG"
}

set_expiry() {
  local pw="$1"; local exp="$2"
  if grep -qF "^${pw}|" "$EXPDB"; then
    sed -i "s|^${pw}|.*|${pw}|${exp}|" "$EXPDB" 2>/dev/null || true
    # fallback if sed regex differs
    awk -F'|' -v p="$pw" -v e="$exp" 'BEGIN{OFS="|"} {if($1==p){$2=e} print}' "$EXPDB" > "${EXPDB}.tmp" && mv "${EXPDB}.tmp" "$EXPDB"
  else
    echo "${pw}|${exp}" >>"$EXPDB"
  fi
}

get_expiry() {
  local pw="$1"
  awk -F'|' -v p="$pw" '$1==p{print $2}' "$EXPDB" | tail -n 1
}

del_expiry() {
  local pw="$1"
  grep -vF "^${pw}|" "$EXPDB" > "${EXPDB}.tmp" 2>/dev/null || true
  mv "${EXPDB}.tmp" "$EXPDB" 2>/dev/null || true
}

add_user() {
  echo -e "${CYAN}== Add Password ==${NC}"
  read -r -p "Password yang mau ditambah: " pw
  read -r -p "Masa aktif (hari, kosong=tanpa expiry): " days

  [[ -z "$pw" ]] && { echo -e "${RED}Password kosong.${NC}"; return; }
  if pw_in_cfg "$pw"; then
    echo -e "${YELLOW}Password sudah ada di config.${NC}"
    return
  fi

  add_pw_to_cfg "$pw"

  if [[ -n "${days:-}" ]]; then
    exp="$(calc_plus_days "$days")"
    set_expiry "$pw" "$exp"
    echo -e "${GREEN}Sukses:${NC} Added + expiry ${YELLOW}${exp}${NC}"
  else
    echo -e "${GREEN}Sukses:${NC} Added (tanpa expiry)"
  fi
}

trial_user() {
  echo -e "${CYAN}== Trial Password ==${NC}"
  local pw days exp
  pw="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 8 2>/dev/null || true)"
  [[ -z "$pw" ]] && pw="trial$RANDOM"
  days="1"
  exp="$(calc_plus_days "$days")"

  if pw_in_cfg "$pw"; then
    echo -e "${YELLOW}Trial bentrok, coba lagi.${NC}"
    return
  fi

  add_pw_to_cfg "$pw"
  set_expiry "$pw" "$exp"

  echo -e "${GREEN}Trial dibuat:${NC}"
  echo -e "  Password : ${YELLOW}${pw}${NC}"
  echo -e "  Exp      : ${YELLOW}${exp}${NC}"
}

renew_user() {
  echo -e "${CYAN}== Renew Password ==${NC}"
  read -r -p "Password yang mau di-renew: " pw
  read -r -p "Tambah masa aktif (hari): " days
  [[ -z "$pw" || -z "$days" ]] && { echo -e "${RED}Input tidak lengkap.${NC}"; return; }

  if ! pw_in_cfg "$pw"; then
    echo -e "${RED}Password tidak ada di config.${NC}"
    return
  fi

  local oldexp newexp
  oldexp="$(get_expiry "$pw")"
  if [[ -z "$oldexp" ]]; then
    newexp="$(calc_plus_days "$days")"
  else
    if is_expired "$oldexp"; then
      newexp="$(calc_plus_days "$days")"
    else
      newexp="$(date -d "${oldexp} +${days} days" +"%Y-%m-%d" 2>/dev/null || calc_plus_days "$days")"
    fi
  fi

  set_expiry "$pw" "$newexp"
  echo -e "${GREEN}Sukses:${NC} Expiry -> ${YELLOW}${newexp}${NC}"
}

delete_user() {
  echo -e "${CYAN}== Delete Password ==${NC}"
  read -r -p "Password yang mau dihapus: " pw
  [[ -z "$pw" ]] && { echo -e "${RED}Kosong.${NC}"; return; }

  if ! pw_in_cfg "$pw"; then
    echo -e "${RED}Password tidak ditemukan di config.${NC}"
    return
  fi

  read -r -p "Yakin hapus password ini? (y/n): " yn
  [[ "$yn" != "y" && "$yn" != "Y" ]] && { echo "Batal."; return; }

  remove_pw_from_cfg "$pw"
  del_expiry "$pw"
  echo -e "${GREEN}Sukses:${NC} Deleted."
}

list_users() {
  echo -e "${CYAN}== List Passwords ==${NC}"
  local arr
  arr="$(jq -r '(.auth.config // [])[]' "$CFG" 2>/dev/null || true)"
  if [[ -z "$arr" ]]; then
    echo -e "${YELLOW}auth.config kosong.${NC}"
    return
  fi

  printf "%-22s %-12s %-10s\n" "PASSWORD" "EXPIRY" "STATUS"
  echo "---------------------------------------------------"
  while IFS= read -r pw; do
    [[ -z "$pw" ]] && continue
    exp="$(get_expiry "$pw")"
    status="OK"
    if [[ -n "$exp" ]] && is_expired "$exp"; then status="EXPIRED"; fi
    printf "%-22s %-12s %-10s\n" "$pw" "${exp:-"-"}" "$status"
  done <<<"$arr"
}

cleanup_expired_now() {
  echo -e "${CYAN}== Cleanup Expired Now ==${NC}"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl start zivpn-expiry-clean.service >/dev/null 2>&1 || true
    echo -e "${GREEN}Triggered expiry cleanup service.${NC}"
  else
    echo -e "${YELLOW}systemctl not found; cleanup via timer not available.${NC}"
  fi
}

restart_service() {
  echo -e "${CYAN}== Restart Service ==${NC}"
  systemctl restart zivpn.service
  systemctl --no-pager status zivpn.service || true
}

show_config() {
  echo -e "${CYAN}== config.json ==${NC}"
  jq . "$CFG" || cat "$CFG"
}

menu_loop() {
  while true; do
    clear
    echo -e "${GREEN}==============================${NC}"
    echo -e "${GREEN}         ZiVPN - MENU         ${NC}"
    echo -e "${GREEN}==============================${NC}"
    echo "  1) Add Password"
    echo "  2) Trial Password (1 day)"
    echo "  3) Renew Password"
    echo "  4) Delete Password"
    echo "  5) List Passwords"
    echo "  6) Cleanup Expired Now"
    echo "  7) Restart ZiVPN Service"
    echo "  8) Show config.json"
    echo "  0) Exit"
    echo -e "${GREEN}==============================${NC}"
    read -r -p "Pilih menu: " opt
    case "$opt" in
      1) add_user; pause ;;
      2) trial_user; pause ;;
      3) renew_user; pause ;;
      4) delete_user; pause ;;
      5) list_users; pause ;;
      6) cleanup_expired_now; pause ;;
      7) restart_service; pause ;;
      8) show_config; pause ;;
      0) exit 0 ;;
      *) echo -e "${RED}Pilihan tidak valid.${NC}"; pause ;;
    esac
  done
}

require_root
need_jq
ensure_paths
menu_loop
