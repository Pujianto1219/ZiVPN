#!/bin/bash
# Script Auto Delete Premium User (AcilShop)
# Lokasi Database: /etc/zivpn/user.db
# Format DB: username tanggal_expired (YYYY-MM-DD)

DATA_DIR="/etc/zivpn"
CONFIG_FILE="$DATA_DIR/config.json"
DB_FILE="$DATA_DIR/user.db"
TODAY=$(date +%Y-%m-%d)

# Cek apakah database ada
if [ ! -f "$DB_FILE" ]; then
    exit 0
fi

while read -r line; do
    USER=$(echo $line | awk '{print $1}')
    EXP_DATE=$(echo $line | awk '{print $2}')

    # Bandingkan Tanggal (String Comparison)
    # Jika Expired Date < Today, maka hapus
    if [[ "$TODAY" > "$EXP_DATE" ]] || [[ "$TODAY" == "$EXP_DATE" ]]; then
        echo "Menghapus User Expired: $USER (Exp: $EXP_DATE)"
        
        # 1. Hapus dari config.json
        sed -i "/\"$USER:/d" "$CONFIG_FILE"

        # 2. Hapus dari database user.db
        sed -i "/^$USER /d" "$DB_FILE"
        
        RESTART_REQUIRED=true
    fi
done < "$DB_FILE"

if [ "$RESTART_REQUIRED" = true ]; then
    systemctl restart zivpn
    echo "Service ZiVPN direstart - User Premium Expired dibersihkan."
fi
