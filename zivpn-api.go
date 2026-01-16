package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
)

type reqUser struct {
	Password string `json:"password"`
	Days     int    `json:"days,omitempty"`
}

func main() {
	port := os.Getenv("ZIVPN_API_PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/api/user/create", withAuth(handleCreate))
	http.HandleFunc("/api/user/renew", withAuth(handleRenew))
	http.HandleFunc("/api/user/delete", withAuth(handleDelete))
	http.HandleFunc("/api/user/info", withAuth(handleInfo))
	http.HandleFunc("/api/cron/expire", withAuth(handleExpire))

	log.Println("ZiVPN API listening on :" + port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func withAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		keyBytes, _ := os.ReadFile("/etc/zivpn/apikey")
		apiKey := strings.TrimSpace(string(keyBytes))
		if apiKey == "" {
			apiKey = "CHANGE_ME"
		}
		if r.Header.Get("X-API-Key") != apiKey {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next(w, r)
	}
}

func decode(w http.ResponseWriter, r *http.Request) (reqUser, bool) {
	var x reqUser
	if err := json.NewDecoder(r.Body).Decode(&x); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return x, false
	}
	if x.Password == "" {
		http.Error(w, "password required", http.StatusBadRequest)
		return x, false
	}
	return x, true
}

// TODO: ganti isi handler sesuai logic ZiVPN kamu
func handleCreate(w http.ResponseWriter, r *http.Request) {
	x, ok := decode(w, r); if !ok { return }
	fmt.Fprintf(w, "Created user %s (%d days)", x.Password, x.Days)
}

func handleRenew(w http.ResponseWriter, r *http.Request) {
	x, ok := decode(w, r); if !ok { return }
	fmt.Fprintf(w, "Renewed user %s (+%d days)", x.Password, x.Days)
}

func handleDelete(w http.ResponseWriter, r *http.Request) {
	x, ok := decode(w, r); if !ok { return }
	fmt.Fprintf(w, "Deleted user %s", x.Password)
}

func handleInfo(w http.ResponseWriter, r *http.Request) {
	x, ok := decode(w, r); if !ok { return }
	fmt.Fprintf(w, "Info user %s: (TODO)", x.Password)
}

func handleExpire(w http.ResponseWriter, r *http.Request) {
	fmt.Fprint(w, "Expire job triggered (TODO)")
}
