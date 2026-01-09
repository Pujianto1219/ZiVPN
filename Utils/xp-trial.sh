#!/bin/bash
# Script Auto Delete Trial User (AcilShop)
# Lokasi Database: /etc/zivpn/trial.db
# Format DB: username expiration_timestamp

DATA_DIR="/etc/zivpn"
CONFIG_FILE="$DATA_DIR/config.json"
DB_FILE="$DATA_DIR/trial.db"
NOW=$(date +%s)

# Cek apakah database ada
if [ ! -f "$DB_FILE" ]; then
    exit 0
fi

# Loop membaca baris per baris database
while read -r line; do
    # Ambil username dan waktu expired dari baris tersebut
    USER=$(echo $line | awk '{print $1}')
    EXP_TIME=$(echo $line | awk '{print $2}')

    # Validasi jika EXP_TIME kosong/bukan angka, skip
    if [[ ! "$EXP_TIME" =~ ^[0-9]+$ ]]; then
        continue
    fi

    # Cek apakah waktu SEKARANG (NOW) lebih besar dari EXP_TIME
    if [ $NOW -ge $EXP_TIME ]; then
        echo "Menghapus Trial Expired: $USER"
        
        # 1. Hapus user dari config.json (Menggunakan sed untuk menghapus baris yang mengandung "user":)
        # Asumsi di config.json formatnya: "user:pass"
        sed -i "/\"$USER:/d" "$CONFIG_FILE"

        # 2. Hapus user dari database trial.db
        sed -i "/^$USER /d" "$DB_FILE"
        
        # 3. Opsional: Hapus user Linux sistem jika ada (userdel -f $USER)
        # userdel -f "$USER" > /dev/null 2>&1

        RESTART_REQUIRED=true
    fi
done < "$DB_FILE"

# Restart Service hanya jika ada yang dihapus (agar tidak spam restart)
if [ "$RESTART_REQUIRED" = true ]; then
    systemctl restart zivpn
    echo "Service ZiVPN direstart karena ada trial dihapus."
fi
