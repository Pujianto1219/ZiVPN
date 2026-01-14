import telebot
from telebot import types
import subprocess
import os
import json
import datetime
import time
import random

# --- KONFIGURASI ---
CONFIG_FILE = "/etc/zivpn/config.json"
USER_DB = "/etc/zivpn/user.db"
TRIAL_DB = "/etc/zivpn/trial.db"
BOT_CONFIG = "/etc/zivpn/bot.json"

# --- CEK CONFIG BOT ---
if not os.path.exists(BOT_CONFIG):
    print("Error: Config Bot belum diset! Jalankan setup.sh dulu.")
    exit()

with open(BOT_CONFIG, 'r') as f:
    config = json.load(f)

TOKEN = config['bot_token']
ADMIN_ID = str(config['admin_id'])

bot = telebot.TeleBot(TOKEN)

# --- FUNGSI SYSTEM ---
def get_sys_info():
    try:
        ram = subprocess.check_output("free -m | awk 'NR==2{printf \"%.2f%%\", $3*100/$2}'", shell=True).decode().strip()
        cpu = subprocess.check_output("top -bn1 | grep load | awk '{printf \"%.2f\", $(NF-2)}'", shell=True).decode().strip()
        # Coba ambil Domain dulu, kalau gak ada ambil IP
        if os.path.exists("/etc/zivpn/domain"):
            with open("/etc/zivpn/domain", "r") as d:
                host = d.read().strip()
        else:
            host = subprocess.check_output("curl -s ifconfig.me", shell=True).decode().strip()
    except:
        return "Unknown", "0%", "0.0"
    return host, ram, cpu

def restart_vpn():
    os.system("systemctl restart zivpn")

# --- MENU UTAMA ---
@bot.message_handler(commands=['start', 'menu'])
def welcome(message):
    if str(message.from_user.id) != ADMIN_ID:
        bot.reply_to(message, "⛔ <b>Access Denied</b>", parse_mode="HTML")
        return

    host, ram, cpu = get_sys_info()
    
    msg_text = f"""
<b>🚀 ZIVPN UDP MANAGER</b>
<code>
┌───────────────┐
│ HOST: {host}
│ RAM : {ram}
│ CPU : {cpu}
└───────────────┘
</code>
"""
    markup = types.InlineKeyboardMarkup(row_width=2)
    btn1 = types.InlineKeyboardButton("👤 Create User", callback_data="add")
    btn2 = types.InlineKeyboardButton("⏳ Trial User", callback_data="trial")
    btn3 = types.InlineKeyboardButton("🗑️ Delete User", callback_data="del")
    btn4 = types.InlineKeyboardButton("📋 List Users", callback_data="list")
    btn5 = types.InlineKeyboardButton("🔄 Restart VPN", callback_data="restart")
    btn6 = types.InlineKeyboardButton("⚙️ VPS Status", callback_data="info")
    
    markup.add(btn1, btn2, btn3, btn4, btn5, btn6)
    bot.send_message(message.chat.id, msg_text, parse_mode="HTML", reply_markup=markup)

# --- CALLBACK HANDLER ---
@bot.callback_query_handler(func=lambda call: True)
def callback(call):
    if str(call.from_user.id) != ADMIN_ID: return

    if call.data == "restart":
        bot.answer_callback_query(call.id, "Restarting UDP Service...")
        restart_vpn()
        bot.send_message(call.message.chat.id, "✅ <b>Service ZiVPN (UDP) Restarted!</b>", parse_mode="HTML")

    elif call.data == "info":
        uptime = subprocess.check_output("uptime -p", shell=True).decode().strip()
        bot.send_message(call.message.chat.id, f"⚙️ <b>Server Uptime:</b>\n<code>{uptime}</code>", parse_mode="HTML")

    elif call.data == "list":
        try:
            with open(CONFIG_FILE, 'r') as f:
                d = json.load(f)
            us = d['auth']['config']
            if not us:
                bot.send_message(call.message.chat.id, "⚠️ Belum ada user yang dibuat.")
            else:
                txt = "<b>📋 User List (UDP):</b>\n" + "\n".join([f"- <code>{u}</code>" for u in us])
                bot.send_message(call.message.chat.id, txt, parse_mode="HTML")
        except:
            bot.send_message(call.message.chat.id, "⚠️ Database Error.")

    elif call.data == "trial":
        # Logic Trial UDP
        u = f"trial{random.randint(100,999)}"
        # Tambah ke JSON
        os.system(f"jq --arg u '{u}' '.auth.config += [$u]' {CONFIG_FILE} > /tmp/t && mv /tmp/t {CONFIG_FILE}")
        # Tambah ke DB Trial (1 Jam)
        exp = int(time.time()) + 3600
        os.system(f"echo '{u} {exp}' >> {TRIAL_DB}")
        restart_vpn()
        
        # Ambil Host
        host, ram, cpu = get_sys_info()
        
        msg = f"""
<b>✅ UDP TRIAL CREATED</b>
<code>
Domain  : {host}
Port    : 5667
Pass    : {u}
Expired : 60 Minutes
</code>
"""
        bot.send_message(call.message.chat.id, msg, parse_mode="HTML")

    elif call.data == "add":
        m = bot.send_message(call.message.chat.id, "📝 <b>Masukkan Username / Password Baru:</b>", parse_mode="HTML")
        bot.register_next_step_handler(m, step_add_1)

    elif call.data == "del":
        m = bot.send_message(call.message.chat.id, "🗑️ <b>Masukkan Username yang akan dihapus:</b>", parse_mode="HTML")
        bot.register_next_step_handler(m, step_del)

# --- LOGIC ADD USER (UDP) ---
def step_add_1(m):
    user = m.text.strip() # Hapus spasi
    # Cek duplikat
    if os.system(f"grep -q '{user}' {CONFIG_FILE}") == 0:
        bot.reply_to(m, "❌ Username/Password sudah ada!")
        return
    msg = bot.reply_to(m, f"User: <b>{user}</b>\n📅 Masukkan Durasi (Hari):", parse_mode="HTML")
    bot.register_next_step_handler(msg, step_add_2, user)

def step_add_2(m, user):
    try: days = int(m.text)
    except: days = 30
    
    # 1. Masukkan ke Config ZiVPN (UDP)
    os.system(f"jq --arg u '{user}' '.auth.config += [$u]' {CONFIG_FILE} > /tmp/t && mv /tmp/t {CONFIG_FILE}")
    
    # 2. Catat Expired
    exp = (datetime.datetime.now() + datetime.timedelta(days=days)).strftime('%Y-%m-%d')
    os.system(f"echo '{user} {exp}' >> {USER_DB}")
    
    # 3. Restart Service
    restart_vpn()
    
    # 4. Tampilkan Detail Akun
    host, ram, cpu = get_sys_info()
    
    detail_akun = f"""
<b>✅ UDP ACCOUNT CREATED</b>
<code>
Domain  : {host}
Port    : 5667
Pass    : {user}
Expired : {exp} ({days} Days)
Network : UDP ZIVPN
</code>
"""
    bot.send_message(m.chat.id, detail_akun, parse_mode="HTML")

# --- LOGIC DELETE USER ---
def step_del(m):
    user = m.text.strip()
    
    # Cek ada atau tidak
    if os.system(f"grep -q '{user}' {CONFIG_FILE}") != 0:
        bot.reply_to(m, "❌ User tidak ditemukan.")
        return

    # Hapus dari Config JSON
    os.system(f"jq --arg u '{user}' '.auth.config -= [$u]' {CONFIG_FILE} > /tmp/t && mv /tmp/t {CONFIG_FILE}")
    # Hapus dari DB
    os.system(f"sed -i '/^{user} /d' {USER_DB}")
    os.system(f"sed -i '/^{user} /d' {TRIAL_DB}")
    
    restart_vpn()
    bot.reply_to(m, f"✅ User <b>{user}</b> berhasil dihapus dari server UDP.", parse_mode="HTML")

print("Bot ZiVPN UDP Running...")
while True:
    try:
        bot.polling(none_stop=True)
    except Exception as e:
        print(f"Error: {e}")
        time.sleep(5)
