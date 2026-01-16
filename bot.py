#!/usr/bin/env python3
import telebot
import json
import os
import sys
import subprocess
import logging
from telebot import types

# --- LOGGING SETUP ---
# Ini penting agar kita tahu kenapa bot error/crash
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

# --- CONFIG LOADER ---
CONFIG_FILE = "/etc/zivpn/bot_config.json"
ZIVPN_CONFIG = "/etc/zivpn/config.json"

# Cek Config Bot
if not os.path.exists(CONFIG_FILE):
    logger.error(f"Config file not found: {CONFIG_FILE}")
    sys.exit(1)

try:
    with open(CONFIG_FILE, 'r') as f:
        config = json.load(f)
    TOKEN = config.get('bot_token')
    ADMIN_ID = str(config.get('admin_id'))
    
    if not TOKEN or not ADMIN_ID:
        raise ValueError("Token or Admin ID is empty")
        
except Exception as e:
    logger.error(f"Failed to load bot config: {e}")
    sys.exit(1)

logger.info("Starting Bot...")
bot = telebot.TeleBot(TOKEN)

# --- HELPER FUNCTIONS ---
def reload_service():
    try:
        subprocess.run(["systemctl", "restart", "zivpn"], check=True)
        return True
    except Exception as e:
        logger.error(f"Failed to reload service: {e}")
        return False

def read_users():
    try:
        if not os.path.exists(ZIVPN_CONFIG):
            return []
        with open(ZIVPN_CONFIG, 'r') as f:
            data = json.load(f)
            # Ambil data auth -> config
            return data.get('auth', {}).get('config', [])
    except Exception as e:
        logger.error(f"Error reading users: {e}")
        return []

def save_users(user_list):
    try:
        with open(ZIVPN_CONFIG, 'r') as f:
            data = json.load(f)
        
        # Pastikan struktur auth ada
        if 'auth' not in data:
            data['auth'] = {}
            
        data['auth']['config'] = user_list
        
        with open(ZIVPN_CONFIG, 'w') as f:
            json.dump(data, f, indent=4)
            
        reload_service()
        return True
    except Exception as e:
        logger.error(f"Error saving users: {e}")
        return False

# --- BOT COMMANDS ---

@bot.message_handler(commands=['start', 'menu'])
def send_welcome(message):
    try:
        if str(message.chat.id) != ADMIN_ID:
            logger.warning(f"Unauthorized access attempt from {message.chat.id}")
            return bot.reply_to(message, "❌ Akses Ditolak!")
        
        markup = types.InlineKeyboardMarkup(row_width=2)
        btn1 = types.InlineKeyboardButton("➕ Create", callback_data="create")
        btn2 = types.InlineKeyboardButton("❌ Delete", callback_data="delete")
        btn3 = types.InlineKeyboardButton("👥 List", callback_data="list")
        btn4 = types.InlineKeyboardButton("♻️ Restart", callback_data="restart")
        markup.add(btn1, btn2, btn3, btn4)
        
        bot.reply_to(message, "🤖 **ZIVPN MANAGER**", reply_markup=markup, parse_mode="Markdown")
    except Exception as e:
        logger.error(f"Error in menu: {e}")

@bot.callback_query_handler(func=lambda call: True)
def callback_query(call):
    if str(call.message.chat.id) != ADMIN_ID:
        return
    
    try:
        if call.data == "create":
            msg = bot.reply_to(call.message, "Format: `user pass` (contoh: `cil 123`)", parse_mode="Markdown")
            bot.register_next_step_handler(msg, process_create)
        
        elif call.data == "delete":
            msg = bot.reply_to(call.message, "Ketik Username yang akan dihapus:")
            bot.register_next_step_handler(msg, process_delete)
            
        elif call.data == "list":
            users = read_users()
            response = f"📋 **Total Users: {len(users)}**\n\n"
            if not users:
                response += "_Tidak ada user_"
            else:
                for u in users:
                    response += f"🔹 `{u}`\n"
            bot.send_message(call.message.chat.id, response, parse_mode="Markdown")
            
        elif call.data == "restart":
            bot.answer_callback_query(call.id, "♻️ Restarting Service...")
            reload_service()
            bot.send_message(call.message.chat.id, "✅ Service Restarted!")
            
    except Exception as e:
        logger.error(f"Error in callback: {e}")

def process_create(message):
    try:
        args = message.text.split()
        if len(args) < 1:
            return bot.reply_to(message, "❌ Format salah.")
            
        username = args[0]
        password = args[1] if len(args) > 1 else "123"
        new_user = f"{username}:{password}"
        
        users = read_users()
        
        # Cek duplikat sederhana
        for u in users:
            if u.startswith(f"{username}:"):
                return bot.reply_to(message, "❌ User sudah ada!")

        users.append(new_user)
        if save_users(users):
            bot.reply_to(message, f"✅ **Created!**\nUser: `{username}`\nPass: `{password}`\n\n_Format login di aplikasi: user:pass_", parse_mode="Markdown")
        else:
            bot.reply_to(message, "❌ Gagal menyimpan ke database.")
            
    except Exception as e:
        logger.error(f"Error create: {e}")
        bot.reply_to(message, "❌ Terjadi kesalahan.")

def process_delete(message):
    try:
        target = message.text.strip()
        users = read_users()
        initial_len = len(users)
        
        # Hapus jika username cocok (user:pass split di :)
        new_list = [u for u in users if u.split(':')[0] != target]
        
        if len(new_list) == initial_len:
            bot.reply_to(message, "❌ User tidak ditemukan.")
        else:
            save_users(new_list)
            bot.reply_to(message, f"✅ User `{target}` dihapus.", parse_mode="Markdown")
    except Exception as e:
        logger.error(f"Error delete: {e}")

# Main Loop
if __name__ == "__main__":
    logger.info("Bot Started Polling...")
    while True:
        try:
            bot.polling(none_stop=True)
        except Exception as e:
            logger.error(f"Bot Polling Error: {e}")
            import time
            time.sleep(5)
