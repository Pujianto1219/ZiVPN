import telebot
import subprocess
import json
import os
import random
import string
import time

# --- SETUP CONFIG ---
# Placeholder ini akan diganti otomatis oleh script Menu saat instalasi
BOT_TOKEN = "DATA_TOKEN"
ADMIN_ID = DATA_ADMIN

CONFIG_FILE = "/etc/zivpn/config.json"

bot = telebot.TeleBot(BOT_TOKEN)

def get_ip():
    try:
        return subprocess.check_output("curl -s ifconfig.me", shell=True).decode().strip()
    except:
        return "127.0.0.1"

def restart_vpn():
    subprocess.call(["systemctl", "restart", "zivpn"])

# --- COMMANDS ---

@bot.message_handler(commands=['start', 'menu'])
def send_welcome(message):
    if str(message.chat.id) != str(ADMIN_ID):
        return bot.reply_to(message, "⛔ Akses Ditolak! ID Anda: " + str(message.chat.id))
    
    markup = telebot.types.ReplyKeyboardMarkup(row_width=2, resize_keyboard=True)
    btn1 = telebot.types.KeyboardButton('/trial')
    btn2 = telebot.types.KeyboardButton('/add')
    btn3 = telebot.types.KeyboardButton('/list')
    btn4 = telebot.types.KeyboardButton('/status')
    markup.add(btn1, btn2, btn3, btn4)
    
    bot.reply_to(message, "👋 *Panel ZiVPN Bot*\nSilakan pilih menu:", parse_mode='Markdown', reply_markup=markup)

@bot.message_handler(commands=['trial'])
def create_trial(message):
    if str(message.chat.id) != str(ADMIN_ID): return
    
    rand_suffix = ''.join(random.choices(string.digits, k=4))
    user = f"trial{rand_suffix}"
    
    try:
        with open(CONFIG_FILE, 'r') as f:
            data = json.load(f)
        
        # Cek duplikat
        if user in data['auth']['config']:
            user = f"trial{rand_suffix}x"
            
        data['auth']['config'].append(user)
        
        with open(CONFIG_FILE, 'w') as f:
            json.dump(data, f, indent=2)
            
        restart_vpn()
        
        ip = get_ip()
        msg = f"✅ *TRIAL SUKSES* ✅\n\nUser: `{user}`\nPass: `{user}`\nIP: `{ip}`\nPort: `5667`"
        bot.reply_to(message, msg, parse_mode='MarkdownV2')
    except Exception as e:
        bot.reply_to(message, f"❌ Error: {str(e)}")

@bot.message_handler(commands=['add'])
def add_user_manual(message):
    if str(message.chat.id) != str(ADMIN_ID): return
    msg = bot.reply_to(message, "Silakan ketik Password/Username baru:")
    bot.register_next_step_handler(msg, process_add_user)

def process_add_user(message):
    new_pass = message.text.strip()
    if not new_pass: return
    
    try:
        with open(CONFIG_FILE, 'r') as f:
            data = json.load(f)
            
        if new_pass in data['auth']['config']:
            return bot.reply_to(message, "❌ Password sudah ada!")
            
        data['auth']['config'].append(new_pass)
        
        with open(CONFIG_FILE, 'w') as f:
            json.dump(data, f, indent=2)
            
        restart_vpn()
        bot.reply_to(message, f"✅ User `{new_pass}` berhasil ditambahkan.", parse_mode='MarkdownV2')
    except Exception as e:
        bot.reply_to(message, f"Error: {str(e)}")

@bot.message_handler(commands=['list'])
def list_users(message):
    if str(message.chat.id) != str(ADMIN_ID): return
    try:
        with open(CONFIG_FILE, 'r') as f:
            data = json.load(f)
        users = data['auth']['config']
        
        if not users:
            bot.reply_to(message, "📭 Belum ada user.")
        else:
            list_txt = "\n".join([f"- `{u}`" for u in users])
            bot.reply_to(message, f"📋 *LIST USER*\n{list_txt}", parse_mode='MarkdownV2')
    except:
        bot.reply_to(message, "Gagal membaca file config.")

@bot.message_handler(commands=['status'])
def check_status(message):
    if str(message.chat.id) != str(ADMIN_ID): return
    try:
        res = subprocess.check_output("systemctl is-active zivpn", shell=True).decode().strip()
        bot.reply_to(message, f"📡 Status Service: *{res.upper()}*", parse_mode='Markdown')
    except:
        bot.reply_to(message, "Service Error.")

print("Bot Berjalan...")
while True:
    try:
        bot.polling(none_stop=True)
    except Exception as e:
        print(f"Error polling: {e}")
        time.sleep(5)
