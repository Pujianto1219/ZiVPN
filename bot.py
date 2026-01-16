import telebot
import json
import os
import subprocess
import random
import string
from telebot import types

# --- CONFIG LOADER ---
CONFIG_FILE = "/etc/zivpn/bot_config.json"
ZIVPN_CONFIG = "/etc/zivpn/config.json"
DB_FILE = "/etc/zivpn/users.db"

# Load Config
with open(CONFIG_FILE, 'r') as f:
    config = json.load(f)

TOKEN = config['bot_token']
ADMIN_ID = str(config['admin_id'])

bot = telebot.TeleBot(TOKEN)

# --- HELPER FUNCTIONS ---
def get_random_password(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def reload_service():
    os.system("systemctl restart zivpn")

def read_users():
    try:
        with open(ZIVPN_CONFIG, 'r') as f:
            data = json.load(f)
            # Pastikan struktur JSON sesuai standard ZiVPN (auth -> config array)
            return data.get('auth', {}).get('config', [])
    except:
        return []

def save_users(user_list):
    with open(ZIVPN_CONFIG, 'r') as f:
        data = json.load(f)
    
    data['auth']['config'] = user_list
    
    with open(ZIVPN_CONFIG, 'w') as f:
        json.dump(data, f, indent=4)
    reload_service()

# --- BOT COMMANDS ---

@bot.message_handler(commands=['start', 'menu'])
def send_welcome(message):
    if str(message.chat.id) != ADMIN_ID:
        return bot.reply_to(message, "❌ Akses Ditolak! Anda bukan Admin.")
    
    markup = types.InlineKeyboardMarkup(row_width=2)
    btn1 = types.InlineKeyboardButton("➕ Create Account", callback_data="create")
    btn2 = types.InlineKeyboardButton("❌ Delete Account", callback_data="delete")
    btn3 = types.InlineKeyboardButton("👥 List Users", callback_data="list")
    btn4 = types.InlineKeyboardButton("♻️ Restart Service", callback_data="restart")
    markup.add(btn1, btn2, btn3, btn4)
    
    bot.reply_to(message, "🤖 **ZIVPN MANAGER BOT**\nSilakan pilih menu:", reply_markup=markup, parse_mode="Markdown")

@bot.callback_query_handler(func=lambda call: True)
def callback_query(call):
    if str(call.message.chat.id) != ADMIN_ID:
        return
    
    if call.data == "create":
        msg = bot.reply_to(call.message, "Masukkan Username & Password (pisahkan spasi).\nContoh: `user1 12345`", parse_mode="Markdown")
        bot.register_next_step_handler(msg, process_create)
    
    elif call.data == "delete":
        msg = bot.reply_to(call.message, "Masukkan Username yang akan dihapus:")
        bot.register_next_step_handler(msg, process_delete)
        
    elif call.data == "list":
        users = read_users()
        response = f"📋 **Total Users: {len(users)}**\n\n"
        for u in users:
            response += f"- `{u}`\n"
        bot.send_message(call.message.chat.id, response, parse_mode="Markdown")
        
    elif call.data == "restart":
        reload_service()
        bot.answer_callback_query(call.id, "✅ Service Restarted!")

def process_create(message):
    try:
        args = message.text.split()
        username = args[0]
        password = args[1] if len(args) > 1 else "1234"
        
        # Format user ZiVPN biasanya "user:pass" atau hanya "pass". 
        # Di sini kita pakai format simple string password sebagai token auth
        new_user = f"{username}-{password}" 
        
        users = read_users()
        if new_user in users:
            bot.reply_to(message, "❌ User sudah ada!")
            return
            
        users.append(new_user)
        save_users(users)
        
        bot.reply_to(message, f"✅ **User Created!**\n\nAuth Token: `{new_user}`\nPort: 6000-19999 (UDP)", parse_mode="Markdown")
    except Exception as e:
        bot.reply_to(message, f"❌ Error: {str(e)}")

def process_delete(message):
    try:
        target = message.text
        users = read_users()
        
        # Simple search and delete
        new_list = [u for u in users if target not in u]
        
        if len(new_list) == len(users):
            bot.reply_to(message, "❌ User tidak ditemukan.")
        else:
            save_users(new_list)
            bot.reply_to(message, "✅ User berhasil dihapus.")
    except Exception as e:
        bot.reply_to(message, f"❌ Error: {str(e)}")

print("Bot is running...")
bot.polling()
