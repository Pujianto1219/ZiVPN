import telebot
import subprocess
import json
import random
import string
import time
from datetime import datetime
import html

# --- SETUP CONFIG ---
BOT_TOKEN = "DATA_TOKEN"
ADMIN_ID = DATA_ADMIN  # pastikan int atau string angka

CONFIG_FILE = "/etc/zivpn/config.json"
VPN_SERVICE = "zivpn"
VPN_PORT = "5667"

bot = telebot.TeleBot(BOT_TOKEN)


# ---------- UTIL ----------
def h(text) -> str:
    """Escape HTML agar aman di parse_mode=HTML."""
    return html.escape(str(text), quote=False)


def banner_acilshop() -> str:
    # HTML-safe, tetap keren
    return (
        "╔══════════════════════════════╗\n"
        "║      🛒 <b>ACILSHOP</b> 🛒        ║\n"
        "║  <i>Fast • Stable • Trusted</i>   ║\n"
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

    auth = data.get("auth", {})
    cfg = auth.get("config", [])
    if not isinstance(cfg, list):
        cfg = []
    return data, cfg


def write_config(data):
    with open(CONFIG_FILE, "w") as f:
        json.dump(data, f, indent=2)


def panel_info_text() -> str:
    try:
        _, users = read_config_users()
        total_users = len(users)
    except:
        total_users = 0

    ip = get_ip()
    status = get_service_status()
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    info_user = (
        "👤 <b>INFO USER</b>\n"
        f"• Total User: <code>{h(total_users)}</code>\n"
        f"• Server IP : <code>{h(ip)}</code>\n"
        f"• Port      : <code>{h(VPN_PORT)}</code>\n"
        f"• Service   : <code>{h(status)}</code>\n"
        f"• Updated   : <code>{h(now)}</code>\n"
    )

    about_bot = (
        "\n🤖 <b>TENTANG BOT</b>\n"
        "• Nama   : <code>ZiVPN Panel Bot</code>\n"
        "• Versi  : <code>1.0</code>\n"
        "• Fitur  : <code>Trial / Add / List / Status</code>\n"
        "• Owner  : <code>AcilShop</code>\n"
        "• Support: <code>@acilshop</code>\n"
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


def is_admin(obj) -> bool:
    chat_id = None
    try:
        chat_id = obj.chat.id  # Message
    except:
        try:
            chat_id = obj.message.chat.id  # CallbackQuery
        except:
            chat_id = None
    return str(chat_id) == str(ADMIN_ID)


def deny(chat_id):
    bot.send_message(chat_id, "⛔ <b>Akses Ditolak!</b>", parse_mode="HTML")


# ---------- COMMANDS ----------
@bot.message_handler(commands=["start", "menu"])
def cmd_start(message):
    if not is_admin(message):
        return bot.reply_to(
            message,
            f"⛔ <b>Akses Ditolak!</b>\nID Anda: <code>{h(message.chat.id)}</code>",
            parse_mode="HTML"
        )

    bot.send_message(
        message.chat.id,
        panel_info_text() + "\nPilih menu di bawah ini:",
        parse_mode="HTML",
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
        return deny(call.message.chat.id)

    data = call.data
    chat_id = call.message.chat.id

    try:
        bot.answer_callback_query(call.id)
    except:
        pass

    if data == "m_refresh":
        try:
            bot.edit_message_text(
                panel_info_text() + "\nPilih menu di bawah ini:",
                chat_id=chat_id,
                message_id=call.message.message_id,
                parse_mode="HTML",
                reply_markup=main_menu_keyboard()
            )
        except:
            bot.send_message(
                chat_id,
                panel_info_text() + "\nPilih menu di bawah ini:",
                parse_mode="HTML",
                reply_markup=main_menu_keyboard()
            )

    elif data == "m_about":
        bot.send_message(chat_id, panel_info_text(), parse_mode="HTML", reply_markup=main_menu_keyboard())

    elif data == "m_status":
        status = get_service_status()
        ip = get_ip()
        txt = (
            banner_acilshop() +
            "📡 <b>STATUS SERVER</b>\n"
            f"• IP      : <code>{h(ip)}</code>\n"
            f"• Port    : <code>{h(VPN_PORT)}</code>\n"
            f"• Service : <code>{h(status)}</code>\n\n"
            "Klik <b>Refresh Panel</b> untuk update info."
        )
        bot.send_message(chat_id, txt, parse_mode="HTML", reply_markup=main_menu_keyboard())

    elif data == "m_list":
        try:
            _, users = read_config_users()
            if not users:
                txt = banner_acilshop() + "📭 <b>Belum ada user.</b>"
            else:
                list_txt = "\n".join([f"• <code>{h(u)}</code>" for u in users])
                txt = banner_acilshop() + "📋 <b>LIST USER</b>\n\n" + list_txt
        except Exception as e:
            txt = banner_acilshop() + f"❌ <b>Gagal membaca config:</b> <code>{h(e)}</code>"

        bot.send_message(chat_id, txt, parse_mode="HTML", reply_markup=main_menu_keyboard())

    elif data == "m_trial":
        rand_suffix = "".join(random.choices(string.digits, k=4))
        user = f"trial{rand_suffix}"

        try:
            data_json, users = read_config_users()

            if user in users:
                user = f"{user}x"

            users.append(user)
            if "auth" not in data_json:
                data_json["auth"] = {}
            data_json["auth"]["config"] = users

            write_config(data_json)
            restart_vpn()

            ip = get_ip()
            txt = (
                banner_acilshop() +
                "✅ <b>TRIAL SUKSES</b> ✅\n\n"
                f"User : <code>{h(user)}</code>\n"
                f"Pass : <code>{h(user)}</code>\n"
                f"IP   : <code>{h(ip)}</code>\n"
                f"Port : <code>{h(VPN_PORT)}</code>\n\n"
                "Gunakan tombol menu untuk aksi lainnya."
            )
            bot.send_message(chat_id, txt, parse_mode="HTML", reply_markup=main_menu_keyboard())

        except Exception as e:
            bot.send_message(
                chat_id,
                banner_acilshop() + f"❌ <b>Error:</b> <code>{h(e)}</code>",
                parse_mode="HTML",
                reply_markup=main_menu_keyboard()
            )

    elif data == "m_add":
        msg = bot.send_message(
            chat_id,
            banner_acilshop() + "✏️ <b>Ketik Username/Password baru:</b>",
            parse_mode="HTML"
        )
        bot.register_next_step_handler(msg, process_add_user_step)

    else:
        bot.send_message(chat_id, "Perintah tidak dikenal.", reply_markup=main_menu_keyboard())


def process_add_user_step(message):
    if not is_admin(message):
        return

    new_pass = (message.text or "").strip()
    if not new_pass:
        return bot.reply_to(message, "❌ <b>Input kosong.</b>", parse_mode="HTML")

    try:
        data_json, users = read_config_users()

        if new_pass in users:
            return bot.send_message(
                message.chat.id,
                banner_acilshop() + "❌ <b>User sudah ada!</b>",
                parse_mode="HTML",
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
            banner_acilshop() + f"✅ <b>User</b> <code>{h(new_pass)}</code> <b>berhasil ditambahkan.</b>",
            parse_mode="HTML",
            reply_markup=main_menu_keyboard()
        )

    except Exception as e:
        bot.send_message(
            message.chat.id,
            banner_acilshop() + f"❌ <b>Error:</b> <code>{h(e)}</code>",
            parse_mode="HTML",
            reply_markup=main_menu_keyboard()
        )


print("🤖 ZiVPN Bot Berjalan...")
while True:
    try:
        bot.polling(none_stop=True)
    except Exception as e:
        print(f"Error polling: {e}")
        time.sleep(5)
