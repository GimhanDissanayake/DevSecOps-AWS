package main

import (
	"log"
	"net/http"
	"os"

	"github.com/GimhanDissanayake/DevSecOps-AWS/apps/user-service/internal/middleware"
	"github.com/GimhanDissanayake/DevSecOps-AWS/apps/user-service/internal/user"
)

func main() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://devuser:devpass@localhost:5432/devsecops?sslmode=disable"
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "dev-secret-change-in-prod"
	}

	handler, err := user.NewHandler(dbURL)
	if err != nil {
		log.Fatal("db connection failed:", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", healthCheck)
	mux.HandleFunc("GET /users", middleware.RequireAuth(jwtSecret, handler.List))
	mux.HandleFunc("GET /users/{id}", middleware.RequireAuth(jwtSecret, handler.Get))
	mux.HandleFunc("PUT /users/{id}", middleware.RequireAuth(jwtSecret, handler.Update))
	mux.HandleFunc("DELETE /users/{id}", middleware.RequireAuth(jwtSecret, handler.Delete))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}

	log.Printf("user-service starting on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, middleware.Logging(mux)))
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"ok","service":"user-service"}`))
}
