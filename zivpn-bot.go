package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
)

const (
	BotConfigFile = "/etc/zivpn/bot-config.json"
	ApiKeyFile    = "/etc/zivpn/apikey"
)

type BotConfig struct {
	BotToken string `json:"bot_token"`
	AdminID  int64  `json:"admin_id"`
	Mode     string `json:"mode"`     // "private" or "public"
	Domain   string `json:"domain"`   // optional
	APIPort  int    `json:"api_port"` // installer isi ini
}

type apiReq struct {
	Password string `json:"password"`
	Days     int    `json:"days,omitempty"`
}

var apiKey string

// ====== UI Callback IDs ======
const (
	cbCreate = "menu:create"
	cbRenew  = "menu:renew"
	cbDelete = "menu:delete"
	cbInfo   = "menu:info"
	cbList   = "menu:list"
	cbHelp   = "menu:help"
	cbCancel = "menu:cancel"
)

// ====== Session / State ======
type Action string

const (
	actNone   Action = ""
	actCreate Action = "create"
	actRenew  Action = "renew"
	actDelete Action = "delete"
	actInfo   Action = "info"
)

type Session struct {
	Action    Action
	Step      int       // 0 none, 1 wait username, 2 wait days (create/renew)
	Username  string
	UpdatedAt time.Time
}

var (
	sessMu   sync.Mutex
	sessions = map[int64]*Session{} // key: chatID
)

func getSession(chatID int64) *Session {
	sessMu.Lock()
	defer sessMu.Unlock()
	s, ok := sessions[chatID]
	if !ok {
		s = &Session{Action: actNone, Step: 0, UpdatedAt: time.Now()}
		sessions[chatID] = s
	}
	// auto-expire session after 10 minutes
	if time.Since(s.UpdatedAt) > 10*time.Minute {
		*s = Session{Action: actNone, Step: 0, UpdatedAt: time.Now()}
	}
	return s
}

func resetSession(chatID int64) {
	sessMu.Lock()
	defer sessMu.Unlock()
	sessions[chatID] = &Session{Action: actNone, Step: 0, UpdatedAt: time.Now()}
}

// ====== Config / API ======
func loadConfig() (*BotConfig, error) {
	b, err := os.ReadFile(BotConfigFile)
	if err != nil {
		return nil, err
	}
	var c BotConfig
	if err := json.Unmarshal(b, &c); err != nil {
		return nil, err
	}
	if c.APIPort == 0 {
		c.APIPort = 8080
	}
	if c.Mode == "" {
		c.Mode = "private"
	}
	return &c, nil
}

func loadAPIKey() {
	if b, err := os.ReadFile(ApiKeyFile); err == nil {
		apiKey = strings.TrimSpace(string(b))
	}
	if apiKey == "" {
		apiKey = "CHANGE_ME"
	}
}

func apiBase(c *BotConfig) string {
	return fmt.Sprintf("http://127.0.0.1:%d/api", c.APIPort)
}

func callAPI(c *BotConfig, path string, body any) (string, error) {
	var buf bytes.Buffer
	if body != nil {
		enc := json.NewEncoder(&buf)
		enc.SetEscapeHTML(false)
		if err := enc.Encode(body); err != nil {
			return "", err
		}
	}
	req, err := http.NewRequest("POST", apiBase(c)+path, &buf)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-API-Key", apiKey)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	rb, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return "", fmt.Errorf("api error: %s", strings.TrimSpace(string(rb)))
	}
	return strings.TrimSpace(string(rb)), nil
}

// Optional: GET list users
func getAPI(c *BotConfig, path string) (string, error) {
	req, err := http.NewRequest("GET", apiBase(c)+path, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("X-API-Key", apiKey)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	rb, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return "", fmt.Errorf("api error: %s", strings.TrimSpace(string(rb)))
	}
	return strings.TrimSpace(string(rb)), nil
}

func isAllowed(c *BotConfig, userID int64) bool {
	if c.Mode == "public" {
		return true
	}
	return userID == c.AdminID
}

// ====== Keyboards ======
func mainMenuKB() tgbotapi.InlineKeyboardMarkup {
	return tgbotapi.NewInlineKeyboardMarkup(
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("➕ Create", cbCreate),
			tgbotapi.NewInlineKeyboardButtonData("♻️ Renew", cbRenew),
		),
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("🗑 Delete", cbDelete),
			tgbotapi.NewInlineKeyboardButtonData("ℹ️ Info", cbInfo),
		),
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("📋 List", cbList),
			tgbotapi.NewInlineKeyboardButtonData("❓ Help", cbHelp),
		),
	)
}

func cancelKB() tgbotapi.InlineKeyboardMarkup {
	return tgbotapi.NewInlineKeyboardMarkup(
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("✖ Cancel", cbCancel),
		),
	)
}

// ====== Main ======
func main() {
	loadAPIKey()
	cfg, err := loadConfig()
	if err != nil {
		log.Fatal("Gagal memuat konfigurasi bot:", err)
	}

	bot, err := tgbotapi.NewBotAPI(cfg.BotToken)
	if err != nil {
		log.Fatal(err)
	}
	bot.Debug = false
	log.Printf("Authorized on account %s", bot.Self.UserName)

	u := tgbotapi.NewUpdate(0)
	u.Timeout = 60
	updates := bot.GetUpdatesChan(u)

	helpText := "Menu perintah:\n" +
		"/start - tampilkan menu\n" +
		"/create <user> <days>\n" +
		"/renew <user> <days>\n" +
		"/delete <user>\n" +
		"/info <user>\n" +
		"/list\n\n" +
		"Atau pakai tombol."

	for upd := range updates {
		// 1) Callback button
		if upd.CallbackQuery != nil {
			cq := upd.CallbackQuery
			if !isAllowed(cfg, cq.From.ID) {
				_ = answerCallback(bot, cq.ID, "Akses ditolak")
				continue
			}
			_ = answerCallback(bot, cq.ID, "OK")
			handleCallback(bot, cfg, cq, helpText)
			continue
		}

		// 2) Messages
		if upd.Message == nil {
			continue
		}

		msg := upd.Message
		if !isAllowed(cfg, msg.From.ID) {
			bot.Send(tgbotapi.NewMessage(msg.Chat.ID, "⛔ Akses ditolak."))
			continue
		}

		txt := strings.TrimSpace(msg.Text)

		// handle session (interactive flow)
		if handled := handleSessionInput(bot, cfg, msg); handled {
			continue
		}

		// commands
		if txt == "/start" {
			resetSession(msg.Chat.ID)
			m := tgbotapi.NewMessage(msg.Chat.ID, "✅ ZiVPN Bot aktif. Pilih menu:")
			m.ReplyMarkup = mainMenuKB()
			bot.Send(m)
			continue
		}
		if txt == "/help" {
			m := tgbotapi.NewMessage(msg.Chat.ID, helpText)
			m.ReplyMarkup = mainMenuKB()
			bot.Send(m)
			continue
		}

		parts := strings.Fields(txt)
		if len(parts) == 0 {
			continue
		}

		switch parts[0] {
		case "/create":
			if len(parts) != 3 {
				bot.Send(tgbotapi.NewMessage(msg.Chat.ID, "Format: /create <user> <days>"))
				continue
			}
			days, _ := strconv.Atoi(parts[2])
			out, err := callAPI(cfg, "/user/create", apiReq{Password: parts[1], Days: days})
			reply(bot, msg.Chat.ID, out, err)

		case "/renew":
			if len(parts) != 3 {
				bot.Send(tgbotapi.NewMessage(msg.Chat.ID, "Format: /renew <user> <days>"))
				continue
			}
			days, _ := strconv.Atoi(parts[2])
			out, err := callAPI(cfg, "/user/renew", apiReq{Password: parts[1], Days: days})
			reply(bot, msg.Chat.ID, out, err)

		case "/delete":
			if len(parts) != 2 {
				bot.Send(tgbotapi.NewMessage(msg.Chat.ID, "Format: /delete <user>"))
				continue
			}
			out, err := callAPI(cfg, "/user/delete", apiReq{Password: parts[1]})
			reply(bot, msg.Chat.ID, out, err)

		case "/info":
			if len(parts) != 2 {
				bot.Send(tgbotapi.NewMessage(msg.Chat.ID, "Format: /info <user>"))
				continue
			}
			out, err := callAPI(cfg, "/user/info", apiReq{Password: parts[1]})
			reply(bot, msg.Chat.ID, out, err)

		case "/list":
			out, err := getAPI(cfg, "/users")
			if err != nil {
				// fallback kalau API kamu belum punya GET /users
				out2, err2 := callAPI(cfg, "/users", map[string]any{})
				if err2 != nil {
					reply(bot, msg.Chat.ID, "", err)
					continue
				}
				out = out2
			}
			if out == "" {
				out = "(empty)"
			}
			m := tgbotapi.NewMessage(msg.Chat.ID, out)
			m.ReplyMarkup = mainMenuKB()
			bot.Send(m)

		default:
			m := tgbotapi.NewMessage(msg.Chat.ID, helpText)
			m.ReplyMarkup = mainMenuKB()
			bot.Send(m)
		}
	}
}

func handleCallback(bot *tgbotapi.BotAPI, cfg *BotConfig, cq *tgbotapi.CallbackQuery, helpText string) {
	chatID := cq.Message.Chat.ID

	switch cq.Data {
	case cbCreate:
		resetSession(chatID)
		s := getSession(chatID)
		s.Action = actCreate
		s.Step = 1
		s.UpdatedAt = time.Now()
		m := tgbotapi.NewMessage(chatID, "➕ Create user\nKirim username (contoh: user123):")
		m.ReplyMarkup = cancelKB()
		bot.Send(m)

	case cbRenew:
		resetSession(chatID)
		s := getSession(chatID)
		s.Action = actRenew
		s.Step = 1
		s.UpdatedAt = time.Now()
		m := tgbotapi.NewMessage(chatID, "♻️ Renew user\nKirim username:")
		m.ReplyMarkup = cancelKB()
		bot.Send(m)

	case cbDelete:
		resetSession(chatID)
		s := getSession(chatID)
		s.Action = actDelete
		s.Step = 1
		s.UpdatedAt = time.Now()
		m := tgbotapi.NewMessage(chatID, "🗑 Delete user\nKirim username:")
		m.ReplyMarkup = cancelKB()
		bot.Send(m)

	case cbInfo:
		resetSession(chatID)
		s := getSession(chatID)
		s.Action = actInfo
		s.Step = 1
		s.UpdatedAt = time.Now()
		m := tgbotapi.NewMessage(chatID, "ℹ️ Info user\nKirim username:")
		m.ReplyMarkup = cancelKB()
		bot.Send(m)

	case cbList:
		out, err := getAPI(cfg, "/users")
		if err != nil {
			out2, err2 := callAPI(cfg, "/users", map[string]any{})
			if err2 != nil {
				reply(bot, chatID, "", err)
				return
			}
			out = out2
		}
		if out == "" {
			out = "(empty)"
		}
		m := tgbotapi.NewMessage(chatID, out)
		m.ReplyMarkup = mainMenuKB()
		bot.Send(m)

	case cbHelp:
		m := tgbotapi.NewMessage(chatID, helpText)
		m.ReplyMarkup = mainMenuKB()
		bot.Send(m)

	case cbCancel:
		resetSession(chatID)
		m := tgbotapi.NewMessage(chatID, "Dibatalkan. Pilih menu:")
		m.ReplyMarkup = mainMenuKB()
		bot.Send(m)
	}
}

func handleSessionInput(bot *tgbotapi.BotAPI, cfg *BotConfig, msg *tgbotapi.Message) bool {
	chatID := msg.Chat.ID
	s := getSession(chatID)

	if s.Action == actNone || s.Step == 0 {
		return false
	}

	text := strings.TrimSpace(msg.Text)
	if text == "" {
		return true
	}

	s.UpdatedAt = time.Now()

	switch s.Step {
	case 1: // wait username
		// allow cancel via typing
		if strings.EqualFold(text, "cancel") || strings.EqualFold(text, "/cancel") {
			resetSession(chatID)
			m := tgbotapi.NewMessage(chatID, "Dibatalkan. Pilih menu:")
			m.ReplyMarkup = mainMenuKB()
			bot.Send(m)
			return true
		}

		s.Username = text
		if s.Action == actCreate || s.Action == actRenew {
			s.Step = 2
			m := tgbotapi.NewMessage(chatID, "Masukkan jumlah hari (contoh: 30):")
			m.ReplyMarkup = cancelKB()
			bot.Send(m)
			return true
		}

		// delete/info: execute now
		if s.Action == actDelete {
			out, err := callAPI(cfg, "/user/delete", apiReq{Password: s.Username})
			resetSession(chatID)
			sendResultWithMenu(bot, chatID, out, err)
			return true
		}
		if s.Action == actInfo {
			out, err := callAPI(cfg, "/user/info", apiReq{Password: s.Username})
			resetSession(chatID)
			sendResultWithMenu(bot, chatID, out, err)
			return true
		}

	case 2: // wait days
		days, err := strconv.Atoi(text)
		if err != nil || days <= 0 {
			bot.Send(tgbotapi.NewMessage(chatID, "❌ Days harus angka > 0. Coba lagi:"))
			return true
		}

		if s.Action == actCreate {
			out, err := callAPI(cfg, "/user/create", apiReq{Password: s.Username, Days: days})
			resetSession(chatID)
			sendResultWithMenu(bot, chatID, out, err)
			return true
		}
		if s.Action == actRenew {
			out, err := callAPI(cfg, "/user/renew", apiReq{Password: s.Username, Days: days})
			resetSession(chatID)
			sendResultWithMenu(bot, chatID, out, err)
			return true
		}
	}

	return true
}

func sendResultWithMenu(bot *tgbotapi.BotAPI, chatID int64, out string, err error) {
	if err != nil {
		m := tgbotapi.NewMessage(chatID, "❌ "+err.Error())
		m.ReplyMarkup = mainMenuKB()
		bot.Send(m)
		return
	}
	if out == "" {
		out = "✅ OK"
	}
	m := tgbotapi.NewMessage(chatID, out)
	m.ReplyMarkup = mainMenuKB()
	bot.Send(m)
}

func reply(bot *tgbotapi.BotAPI, chatID int64, out string, err error) {
	if err != nil {
		bot.Send(tgbotapi.NewMessage(chatID, "❌ "+err.Error()))
		return
	}
	if out == "" {
		out = "✅ OK"
	}
	bot.Send(tgbotapi.NewMessage(chatID, out))
}

func answerCallback(bot *tgbotapi.BotAPI, callbackID, text string) error {
	cfg := tgbotapi.NewCallback(callbackID, text)
	_, err := bot.Request(cfg)
	return err
}
