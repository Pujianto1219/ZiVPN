package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"
)

const (
	apiKeyFile   = "/etc/zivpn/apikey"
	usersDBFile  = "/etc/zivpn/users.json"
	passwordFile = "/etc/zivpn/zi" // sesuai config.json: "config": ["zi"] 2
)

var (
	mu           sync.Mutex
	usernameRe   = regexp.MustCompile(`^[a-zA-Z0-9_]{3,32}$`)
	serverTZ, _  = time.LoadLocation("Asia/Jakarta")
)

type UserRec struct {
	Password string `json:"password"`
	Expired  string `json:"expired"`  // YYYY-MM-DD
	Created  string `json:"created"`  // YYYY-MM-DD
	Status   string `json:"status"`   // active/expired
}

type Req struct {
	Password string `json:"password"`
	Days     int    `json:"days"`
}

func main() {
	port := os.Getenv("ZIVPN_API_PORT")
	if port == "" {
		// AutoFTbot default pakai 8080, tapi install.sh mereka cari port kosong lalu simpan di /etc/zivpn/api_port 3
		port = "8080"
	}

	mux := http.NewServeMux()

	// POST
	mux.HandleFunc("/api/user/create", withAuth(handleCreate))
	mux.HandleFunc("/api/user/renew", withAuth(handleRenew))
	mux.HandleFunc("/api/user/delete", withAuth(handleDelete))
	mux.HandleFunc("/api/cron/expire", withAuth(handleExpire))

	// GET
	mux.HandleFunc("/api/users", withAuth(handleList))
	mux.HandleFunc("/api/info", withAuth(handleInfo))

	fmt.Println("ZiVPN API listening on :" + port)
	_ = http.ListenAndServe(":"+port, mux)
}

func withAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		key := strings.TrimSpace(readFile(apiKeyFile))
		if key == "" {
			key = "CHANGE_ME"
		}
		if r.Header.Get("X-API-Key") != key {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next(w, r)
	}
}

func decodeReq(r *http.Request) (Req, error) {
	var x Req
	if err := json.NewDecoder(r.Body).Decode(&x); err != nil {
		return x, errors.New("bad json body")
	}
	x.Password = strings.TrimSpace(x.Password)
	return x, nil
}

func handleCreate(w http.ResponseWriter, r *http.Request) {
	mu.Lock()
	defer mu.Unlock()

	x, err := decodeReq(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest); return
	}
	if !usernameRe.MatchString(x.Password) {
		http.Error(w, "invalid username (use 3-32 chars: a-zA-Z0-9_)", http.StatusBadRequest); return
	}
	if x.Days <= 0 || x.Days > 3650 {
		http.Error(w, "days must be 1..3650", http.StatusBadRequest); return
	}

	users := loadUsers()
	if _, ok := users[x.Password]; ok {
		http.Error(w, "user already exists", http4
