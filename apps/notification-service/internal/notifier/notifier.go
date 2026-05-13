package notifier

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/redis/go-redis/v9"
)

const queueName = "notifications"

type Service struct {
	rdb *redis.Client
}

type Notification struct {
	UserID  string `json:"user_id"`
	Type    string `json:"type"`
	Message string `json:"message"`
}

func New(redisAddr string) *Service {
	rdb := redis.NewClient(&redis.Options{
		Addr: redisAddr,
	})
	return &Service{rdb: rdb}
}

func (s *Service) Enqueue(w http.ResponseWriter, r *http.Request) {
	var n Notification
	if err := json.NewDecoder(r.Body).Decode(&n); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	if n.UserID == "" || n.Type == "" || n.Message == "" {
		http.Error(w, `{"error":"user_id, type, and message are required"}`, http.StatusBadRequest)
		return
	}

	data, _ := json.Marshal(n)
	ctx := context.Background()
	if err := s.rdb.LPush(ctx, queueName, data).Err(); err != nil {
		http.Error(w, `{"error":"failed to enqueue"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusAccepted)
	w.Write([]byte(`{"status":"queued"}`))
}

func (s *Service) ProcessQueue() {
	ctx := context.Background()
	log.Println("notification worker started")

	for {
		result, err := s.rdb.BRPop(ctx, 5*time.Second, queueName).Result()
		if err != nil {
			continue
		}

		var n Notification
		if err := json.Unmarshal([]byte(result[1]), &n); err != nil {
			log.Printf("invalid notification payload: %v", err)
			continue
		}

		// Simulate sending notification (email, SMS, push)
		log.Printf("SENT [%s] to user %s: %s", n.Type, n.UserID, n.Message)
	}
}
