package main

import (
	"log"
	"net/http"
	"os"

	"github.com/GimhanDissanayake/DevSecOps-AWS/apps/order-service/internal/middleware"
	"github.com/GimhanDissanayake/DevSecOps-AWS/apps/order-service/internal/order"
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

	handler, err := order.NewHandler(dbURL)
	if err != nil {
		log.Fatal("db connection failed:", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", healthCheck)
	mux.HandleFunc("POST /orders", middleware.RequireAuth(jwtSecret, handler.Create))
	mux.HandleFunc("GET /orders", middleware.RequireAuth(jwtSecret, handler.List))
	mux.HandleFunc("GET /orders/{id}", middleware.RequireAuth(jwtSecret, handler.Get))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8082"
	}

	log.Printf("order-service starting on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, middleware.Logging(mux)))
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"ok","service":"order-service"}`))
}
