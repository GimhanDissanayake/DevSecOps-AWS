package main

import (
	"log"
	"net/http"
	"os"

	"github.com/GimhanDissanayake/DevSecOps-AWS/apps/auth-service/internal/auth"
	"github.com/GimhanDissanayake/DevSecOps-AWS/apps/auth-service/internal/db"
	"github.com/GimhanDissanayake/DevSecOps-AWS/apps/auth-service/internal/middleware"
)

func main() {
	database, err := db.Connect(os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal("db connection failed:", err)
	}
	defer database.Close()

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "dev-secret-change-in-prod"
	}

	handler := auth.NewHandler(database, jwtSecret)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", healthCheck)
	mux.HandleFunc("POST /auth/register", handler.Register)
	mux.HandleFunc("POST /auth/login", handler.Login)
	mux.HandleFunc("POST /auth/refresh", handler.Refresh)
	mux.HandleFunc("GET /auth/me", middleware.RequireAuth(jwtSecret, handler.Me))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("auth-service starting on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, middleware.Logging(mux)))
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"ok","service":"auth-service"}`))
}
