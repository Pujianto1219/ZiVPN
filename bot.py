import telebot
from telebot import types
import subprocess
import os
import json
import datetime
import time
import random

# ==========================================
# KONFIGURASI FILE & DATABASE
# ==========================================
CONFIG_FILE = "/etc/zivpn/config.json"
USER_DB = "/etc/zivpn/user.db"
TRIAL_DB = "/etc/zivpn/trial.db"
BOT_CONFIG = "/etc/zivpn/bot.json"

# Load Config Bot (Token & Admin ID)
if not os.path.exists(BOT_CONFIG):
    print("Error: File bot.json tidak ditemukan! Jalankan menu -> Setup Bot dulu.")
    exit()

with open(BOT_CONFIG, 'r') as f:
    config = json.load(f)

TOKEN = config['bot_token']
ADMIN_ID = str(config['admin_id'])

bot = telebot.TeleBot(TOKEN)

# ==========================================
# HELPER FUNCTIONS
# ==========================================
def get_system_info():
    # Ambil RAM
    ram_cmd = "free -m | awk 'NR==2{printf \"%.2f%%\", $3*100/$2}'"
    ram = subprocess.check_output(ram_cmd, shell=True).decode().strip()
    
    # Ambil CPU Load
    cpu_cmd = "top -bn1 | grep load | awk '{printf \"%.2f\", $(NF-2)}'"
    try:
        cpu = subprocess.check_output(cpu_cmd, shell=True).decode().strip()
    except:
        cpu = "0.0"

    # Ambil IP
    ip_cmd = "curl -s ifconfig.me"
    try:
        ip = subprocess.check_output(ip_cmd, shell=True).decode().strip()
    except:
        ip = "Unknown"

    return ip, ram, cpu

def restart_vpn():
    os.system("systemctl restart zivpn")

# ==========================================
# TAMPILAN MENU (BANNER & BUTTONS)
# ==========================================
@bot.message_handler(commands=['start', 'menu'])
def send_welcome(message):
    # Security Check: Hanya Admin yang bisa akses
    if str(message.from_user.id) != ADMIN_ID:
        bot.reply_to(message, "⛔ <b>ACCESS DENIED</b>\nAnda bukan Admin bot ini!", parse_mode="HTML")
        return

    ip, ram, cpu = get_system_info()
    
    # Banner Style Console (Monospace)
    banner_text = f"""
<b>≡ ZIVPN PREMIUM CONTROL ≡</b>
<code>
┌───────────────────────────┐
│ SERVER STATUS INFORMATION │
├───────────────────────────┤
│ IP   : {ip}
│ RAM  : {ram}
│ CPU  : {cpu}
│ DATE : {datetime.datetime.now().strftime("%Y-%m-%d %H:%M")}
└───────────────────────────┘
</code>
<b>Select Menu Option:</b>
"""
    
    # Membuat Keyboard 2 Kolom (Grid)
    markup = types.InlineKeyboardMarkup(row_width=2)
    
    btn1 = types.InlineKeyboardButton("👤 Create User", callback_data="add_user")
    btn2 = types.InlineKeyboardButton("⏳ Trial Account", callback_data="trial_user")
    btn3 = types.InlineKeyboardButton("🗑️ Delete User", callback_data="del_user")
    btn4 = types.InlineKeyboardButton("📄 List Users", callback_data="list_user")
    btn5 = types.InlineKeyboardButton("🔄 Restart VPN", callback_data="restart")
    btn6 = types.InlineKeyboardButton("⚙️ System Info", callback_data="sys_info")
    
    markup.add(btn1, btn2)
    markup.add(btn3, btn4)
    markup.add(btn5, btn6)

    bot.send_message(message.chat.id, banner_text, parse_mode="HTML", reply_markup=markup)

# ==========================================
# CALLBACK HANDLER (LOGIKA TOMBOL)
# ==========================================
@bot.callback_query_handler(func=lambda call: True)
def callback_query(call):
    if str(call.from_user.id) != ADMIN_ID:
        return

    if call.data == "sys_info":
        ip, ram, cpu = get_system_info()
        info_text = f"""
<b>⚙️ SYSTEM DETAILS</b>
<code>
OS     : Ubuntu/Debian
IP     : {ip}
RAM    : {ram}
CPU    : {cpu}
UPTIME : {subprocess.check_output("uptime -p", shell=True).decode().strip()}
</code>
"""
        bot.send_message(call.message.chat.id, info_text, parse_mode="HTML")

    elif call.data == "restart":
        msg = bot.send_message(call.message.chat.id, "🔄 <i>Restarting ZIVPN Service...</i>", parse_mode="HTML")
        restart_vpn()
        time.sleep(2)
        bot.edit_message_text("✅ <b>Service Restarted Successfully!</b>", call.message.chat.id, msg.message_id, parse_mode="HTML")

    elif call.data == "list_user":
        try:
            # Baca Config JSON
            with open(CONFIG_FILE, 'r') as f:
                data = json.load(f)
            
            users = data['auth']['config']
            if not users:
                bot.send_message(call.message.chat.id, "📂 <b>Database Kosong.</b> Belum ada user.", parse_mode="HTML")
            else:
                # Format List Rapi
                response = "<b>📋 LIST USER ZIVPN:</b>\n<code>"
                for i, u in enumerate(users, 1):
                    response += f"{i}. {u}\n"
                response += "</code>"
                bot.send_message(call.message.chat.id, response, parse_mode="HTML")
        except Exception as e:
            bot.send_message(call.message.chat.id, f"Error: {e}")

    elif call.data == "trial_user":
        # Generate Random Trial
        rand_id = random.randint(1000, 9999)
        username = f"trial{rand_id}"
        
        # 1. Update JSON
        os.system(f"jq --arg u '{username}' '.auth.config += [$u]' {CONFIG_FILE} > /tmp/conf && mv /tmp/conf {CONFIG_FILE}")
        
        # 2. Update Database (60 Menit)
        exp_timestamp = int(time.time()) + 3600 # 60 menit
        os.system(f"echo '{username} {exp_timestamp}' >> {TRIAL_DB}")
        
        restart_vpn()
        
        msg_trial = f"""
<b>✅ TRIAL CREATED!</b>
<code>
Username : {username}
Expired  : 60 Minutes
Limit    : 1 Device
</code>
"""
        bot.send_message(call.message.chat.id, msg_trial, parse_mode="HTML")

    elif call.data == "add_user":
        msg = bot.send_message(call.message.chat.id, "📝 <b>Masukkan Username Baru:</b>", parse_mode="HTML")
        bot.register_next_step_handler(msg, process_add_user_step1)

    elif call.data == "del_user":
        msg = bot.send_message(call.message.chat.id, "🗑️ <b>Masukkan Username yang akan dihapus:</b>", parse_mode="HTML")
        bot.register_next_step_handler(msg, process_del_user)

# ==========================================
# PROSES INPUT (ADD USER)
# ==========================================
def process_add_user_step1(message):
    username = message.text.strip()
    
    # Cek apakah user ada (grep simple)
    if os.system(f"grep -q '{username}' {CONFIG_FILE}") == 0:
        bot.reply_to(message, "❌ <b>Error:</b> Username sudah ada!", parse_mode="HTML")
        return

    msg = bot.reply_to(message, f"Username: <b>{username}</b>\n📅 <b>Masukkan Durasi (Hari):</b>\n(Contoh: 30)", parse_mode="HTML")
    bot.register_next_step_handler(msg, process_add_user_step2, username)

def process_add_user_step2(message, username):
    try:
        days = int(message.text.strip())
    except ValueError:
        days = 30 # Default
    
    # 1. Update JSON
    os.system(f"jq --arg u '{username}' '.auth.config += [$u]' {CONFIG_FILE} > /tmp/conf && mv /tmp/conf {CONFIG_FILE}")
    
    # 2. Hitung Expired & Update DB
    # Format DB User: username YYYY-MM-DD
    expiry_date = (datetime.datetime.now() + datetime.timedelta(days=days)).strftime('%Y-%m-%d')
    os.system(f"echo '{username} {expiry_date}' >> {USER_DB}")
    
    restart_vpn()
    
    # Tampilkan Detail
    # Ambil IP/Domain untuk info
    try:
        domain = subprocess.check_output(f"cat /etc/zivpn/domain", shell=True).decode().strip()
    except:
        domain = "IP-VPS-ANDA"

    result_text = f"""
<b>✅ USER CREATED SUCCESSFULLY!</b>
<code>
Username : {username}
Expired  : {expiry_date} ({days} Days)
Host/IP  : {domain}
Port UDP : 5667
</code>
"""
    bot.send_message(message.chat.id, result_text, parse_mode="HTML")

# ==========================================
# PROSES INPUT (DELETE USER)
# ==========================================
def process_del_user(message):
    username = message.text.strip()
    
    # Cek Keberadaan User
    if os.system(f"grep -q '{username}' {CONFIG_FILE}") != 0:
        bot.reply_to(message, "❌ <b>Error:</b> Username tidak ditemukan!", parse_mode="HTML")
        return

    # Hapus dari JSON
    os.system(f"jq --arg u '{username}' '.auth.config -= [$u]' {CONFIG_FILE} > /tmp/conf && mv /tmp/conf {CONFIG_FILE}")
    
    # Hapus dari DB User & Trial
    os.system(f"sed -i '/^{username} /d' {USER_DB}")
    os.system(f"sed -i '/^{username} /d' {TRIAL_DB}")
    
    restart_vpn()
    
    bot.reply_to(message, f"🗑️ User <b>{username}</b> berhasil dihapus!", parse_mode="HTML")

# ==========================================
# POLLING (LOOPING BOT)
# ==========================================
print("Bot ZIVPN Berjalan...")
while True:
    try:
        bot.polling(none_stop=True)
    except Exception as e:
        print(f"Connection Error: {e}")
        time.sleep(5)
