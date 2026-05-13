package main

import (
	"log"
	"net/http"
	"os"

	"github.com/GimhanDissanayake/DevSecOps-AWS/apps/notification-service/internal/notifier"
)

func main() {
	redisAddr := os.Getenv("REDIS_URL")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}

	svc := notifier.New(redisAddr)

	// Start background worker to process notification queue
	go svc.ProcessQueue()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", healthCheck)
	mux.HandleFunc("POST /notifications/send", svc.Enqueue)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8083"
	}

	log.Printf("notification-service starting on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"ok","service":"notification-service"}`))
}
