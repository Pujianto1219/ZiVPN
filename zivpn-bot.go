package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"

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

	rb, _ := ioutil.ReadAll(resp.Body)
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

	help := "Perintah:\n" +
		"/start\n" +
		"/create <user> <days>\n" +
		"/renew <user> <days>\n" +
		"/delete <user>\n" +
		"/info <user>\n"

	for upd := range updates {
		if upd.Message == nil {
			continue
		}
		msg := upd.Message
		if !isAllowed(cfg, msg.From.ID) {
			bot.Send(tgbotapi.NewMessage(msg.Chat.ID, "⛔ Akses ditolak."))
			continue
		}

		txt := strings.TrimSpace(msg.Text)
		if txt == "/start" {
			bot.Send(tgbotapi.NewMessage(msg.Chat.ID, "✅ ZiVPN Bot aktif.\n\n"+help))
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

		default:
			bot.Send(tgbotapi.NewMessage(msg.Chat.ID, help))
		}
	}
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
