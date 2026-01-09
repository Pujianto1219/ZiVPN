import telebot
import subprocess
import json
import random
import string
import time
from datetime import datetime

# --- SETUP CONFIG ---
BOT_TOKEN = "DATA_TOKEN"
ADMIN_ID = DATA_ADMIN  # pastikan angka / int, atau string yg valid

CONFIG_FILE = "/etc/zivpn/config.json"
VPN_SERVICE = "zivpn"
VPN_PORT = "5667"

bot = telebot.TeleBot(BOT_TOKEN)


# ---------- UTIL: MARKDOWNV2 SAFE ----------
def mdv2_escape(text: str) -> str:
    """
    Escape karakter khusus MarkdownV2 Telegram.
    """
    if text is None:
        return ""
    escape_chars = r"_*[]()~`>#+-=|{}.!\\"
    out = []
    for ch in str(text):
        if ch in escape_chars:
            out.append("\\" + ch)
        else:
            out.append(ch)
    return "".join(out)


# ---------- BANNER / KOLOM ----------
def banner_acilshop() -> str:
    # aman untuk MarkdownV2 (tanpa karakter yang rawan/di-escape berlebihan)
    return (
        "╔══════════════════════════════╗\n"
        "║      🛒 *ACILSHOP* 🛒         ║\n"
        "║  _Fast • Stable • Trusted_    ║\n"
        "║  Support: @acilshop           ║\n"
        "╚══════════════════════════════╝\n\n"
    )


def get_ip() -> str:
    try:
        return subprocess.check_output("curl -s ifconfig.me", shell=True).decode().strip()
    except:
        return "127.0.0.1"


def get_service_status() -> str:
    try:
        res = subprocess.check_output(f"systemctl is-active {VPN_SERVICE}", shell=True).decode().strip()
        return res.upper()
    except:
        return "UNKNOWN"


def restart_vpn():
    subprocess.call(["systemctl", "restart", VPN_SERVICE])


def read_config_users():
    with open(CONFIG_FILE, "r") as f:
        data = json.load(f)

    # aman kalau struktur berubah sedikit
    auth = data.get("auth", {})
    cfg = auth.get("config", [])
    if not isinstance(cfg, list):
        cfg = []
    return data, cfg


def write_config(data):
    with open(CONFIG_FILE, "w") as f:
        json.dump(data, f, indent=2)


def panel_info_text() -> str:
    """
    Kolom: Info user + tentang bot
    """
    try:
        _, users = read_config_users()
        total_users = len(users)
    except:
        total_users = 0

    ip = get_ip()
    status = get_service_status()
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    info_user = (
        "👤 *INFO USER*\n"
        f"• Total User: `{mdv2_escape(total_users)}`\n"
        f"• Server IP : `{mdv2_escape(ip)}`\n"
        f"• Port      : `{mdv2_escape(VPN_PORT)}`\n"
        f"• Service   : `{mdv2_escape(status)}`\n"
        f"• Updated   : `{mdv2_escape(now)}`\n"
    )

    about_bot = (
        "\n🤖 *TENTANG BOT*\n"
        "• Nama   : `ZiVPN Panel Bot`\n"
        "• Versi  : `1.0`\n"
        "• Fitur  : `Trial / Add / List / Status`\n"
        "• Owner  : `AcilShop`\n"
        "• Support: `@acilshop`\n"
    )

    return banner_acilshop() + info_user + about_bot


# ---------- INLINE BUTTON MENU ----------
def main_menu_keyboard():
    kb = telebot.types.InlineKeyboardMarkup(row_width=2)
    kb.add(
        telebot.types.InlineKeyboardButton("🎁 Trial", callback_data="m_trial"),
        telebot.types.InlineKeyboardButton("➕ Add User", callback_data="m_add"),
        telebot.types.InlineKeyboardButton("📋 List User", callback_data="m_list"),
        telebot.types.InlineKeyboardButton("📡 Status", callback_data="m_status"),
    )
    kb.add(
        telebot.types.InlineKeyboardButton("ℹ️ About / Info", callback_data="m_about"),
        telebot.types.InlineKeyboardButton("🔄 Refresh Panel", callback_data="m_refresh"),
    )
    return kb


def is_admin(message_or_call) -> bool:
    # message_or_call bisa Message atau CallbackQuery
    chat_id = None
    try:
        chat_id = message_or_call.chat.id  # Message
    except:
        try:
            chat_id = message_or_call.message.chat.id  # CallbackQuery
        except:
            chat_id = None

    return str(chat_id) == str(ADMIN_ID)


def deny_text(chat_id):
    return bot.send_message(
        chat_id,
        "⛔ *Akses Ditolak\\!*",
        parse_mode="MarkdownV2"
    )


# ---------- COMMANDS ----------
@bot.message_handler(commands=["start", "menu"])
def cmd_start(message):
    if not is_admin(message):
        return bot.reply_to(
            message,
            "⛔ *Akses Ditolak\\!*\\nID Anda: `" + mdv2_escape(message.chat.id) + "`",
            parse_mode="MarkdownV2"
        )

    bot.send_message(
        message.chat.id,
        panel_info_text() + "\nPilih menu di bawah ini:",
        parse_mode="MarkdownV2",
        reply_markup=main_menu_keyboard()
    )


# ---------- CALLBACK HANDLER ----------
@bot.callback_query_handler(func=lambda c: True)
def on_callback(call):
    if not is_admin(call):
        try:
            bot.answer_callback_query(call.id, "Akses ditolak!", show_alert=True)
        except:
            pass
        return deny_text(call.message.chat.id)

    data = call.data
    chat_id = call.message.chat.id

    # biar tombol tidak "loading" terus
    try:
        bot.answer_callback_query(call.id)
    except:
        pass

    if data == "m_refresh":
        # edit message panel biar rapi
        try:
            bot.edit_message_text(
                panel_info_text() + "\nPilih menu di bawah ini:",
                chat_id=chat_id,
                message_id=call.message.message_id,
                parse_mode="MarkdownV2",
                reply_markup=main_menu_keyboard()
            )
        except:
            bot.send_message(
                chat_id,
                panel_info_text() + "\nPilih menu di bawah ini:",
                parse_mode="MarkdownV2",
                reply_markup=main_menu_keyboard()
            )

    elif data == "m_about":
        bot.send_message(
            chat_id,
            panel_info_text(),
            parse_mode="MarkdownV2",
            reply_markup=main_menu_keyboard()
        )

    elif data == "m_status":
        status = get_service_status()
        ip = get_ip()
        txt = (
            banner_acilshop() +
            "📡 *STATUS SERVER*\n"
            f"• IP      : `{mdv2_escape(ip)}`\n"
            f"• Port    : `{mdv2_escape(VPN_PORT)}`\n"
            f"• Service : `{mdv2_escape(status)}`\n\n"
            "Klik *Refresh Panel* untuk update info."
        )
        bot.send_message(chat_id, txt, parse_mode="MarkdownV2", reply_markup=main_menu_keyboard())

    elif data == "m_list":
        try:
            _, users = read_config_users()
            if not users:
                txt = banner_acilshop() + "📭 *Belum ada user.*"
            else:
                list_txt = "\n".join([f"• `{mdv2_escape(u)}`" for u in users])
                txt = banner_acilshop() + "📋 *LIST USER*\n\n" + list_txt
        except Exception as e:
            txt = banner_acilshop() + f"❌ *Gagal membaca config:* `{mdv2_escape(e)}`"

        bot.send_message(chat_id, txt, parse_mode="MarkdownV2", reply_markup=main_menu_keyboard())

    elif data == "m_trial":
        rand_suffix = "".join(random.choices(string.digits, k=4))
        user = f"trial{rand_suffix}"

        try:
            data_json, users = read_config_users()

            # Cek duplikat
            if user in users:
                user = f"{user}x"

            users.append(user)
            # pastikan struktur balik sesuai
            if "auth" not in data_json:
                data_json["auth"] = {}
            data_json["auth"]["config"] = users

            write_config(data_json)
            restart_vpn()

            ip = get_ip()
            txt = (
                banner_acilshop() +
                "✅ *TRIAL SUKSES* ✅\n\n"
                f"User : `{mdv2_escape(user)}`\n"
                f"Pass : `{mdv2_escape(user)}`\n"
                f"IP   : `{mdv2_escape(ip)}`\n"
                f"Port : `{mdv2_escape(VPN_PORT)}`\n\n"
                "Gunakan tombol menu untuk aksi lainnya."
            )
            bot.send_message(chat_id, txt, parse_mode="MarkdownV2", reply_markup=main_menu_keyboard())

        except Exception as e:
            bot.send_message(
                chat_id,
                banner_acilshop() + f"❌ Error: `{mdv2_escape(e)}`",
                parse_mode="MarkdownV2",
                reply_markup=main_menu_keyboard()
            )

    elif data == "m_add":
        msg = bot.send_message(
            chat_id,
            banner_acilshop() + "✏️ *Ketik Username/Password baru:*",
            parse_mode="MarkdownV2"
        )
        bot.register_next_step_handler(msg, process_add_user_step)

    else:
        bot.send_message(chat_id, "Perintah tidak dikenal.", reply_markup=main_menu_keyboard())


def process_add_user_step(message):
    if not is_admin(message):
        return

    new_pass = (message.text or "").strip()
    if not new_pass:
        return bot.reply_to(message, "❌ Input kosong.", parse_mode="MarkdownV2")

    try:
        data_json, users = read_config_users()

        if new_pass in users:
            return bot.reply_to(
                message,
                banner_acilshop() + "❌ *User sudah ada\\!*",
                parse_mode="MarkdownV2",
                reply_markup=main_menu_keyboard()
            )

        users.append(new_pass)
        if "auth" not in data_json:
            data_json["auth"] = {}
        data_json["auth"]["config"] = users

        write_config(data_json)
        restart_vpn()

        bot.send_message(
            message.chat.id,
            banner_acilshop() + f"✅ User `{mdv2_escape(new_pass)}` berhasil ditambahkan.",
            parse_mode="MarkdownV2",
            reply_markup=main_menu_keyboard()
        )

    except Exception as e:
        bot.send_message(
            message.chat.id,
            banner_acilshop() + f"❌ Error: `{mdv2_escape(e)}`",
            parse_mode="MarkdownV2",
            reply_markup=main_menu_keyboard()
        )


print("🤖 ZiVPN Bot Berjalan...")
while True:
    try:
        bot.polling(none_stop=True)
    except Exception as e:
        print(f"Error polling: {e}")
        time.sleep(5)
