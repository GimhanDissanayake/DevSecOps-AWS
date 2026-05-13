package order

import (
	"database/sql"
	"encoding/json"
	"net/http"

	_ "github.com/lib/pq"
)

type Handler struct {
	db *sql.DB
}

type Order struct {
	ID        string  `json:"id"`
	UserID    string  `json:"user_id"`
	Item      string  `json:"item"`
	Quantity  int     `json:"quantity"`
	Total     float64 `json:"total"`
	Status    string  `json:"status"`
	CreatedAt string  `json:"created_at"`
}

func NewHandler(dbURL string) (*Handler, error) {
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		return nil, err
	}
	if err := db.Ping(); err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	return &Handler{db: db}, nil
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(string)

	var body struct {
		Item     string  `json:"item"`
		Quantity int     `json:"quantity"`
		Price    float64 `json:"price"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	if body.Item == "" || body.Quantity <= 0 || body.Price <= 0 {
		http.Error(w, `{"error":"item, quantity, and price are required"}`, http.StatusBadRequest)
		return
	}

	total := body.Price * float64(body.Quantity)
	var id string
	err := h.db.QueryRow(
		`INSERT INTO orders (user_id, item, quantity, total, status) VALUES ($1, $2, $3, $4, 'pending') RETURNING id`,
		userID, body.Item, body.Quantity, total,
	).Scan(&id)
	if err != nil {
		http.Error(w, `{"error":"internal error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"id": id, "total": total, "status": "pending",
	})
}

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(string)

	rows, err := h.db.Query(
		`SELECT id, user_id, item, quantity, total, status, created_at FROM orders WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50`,
		userID,
	)
	if err != nil {
		http.Error(w, `{"error":"internal error"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	orders := []Order{}
	for rows.Next() {
		var o Order
		if err := rows.Scan(&o.ID, &o.UserID, &o.Item, &o.Quantity, &o.Total, &o.Status, &o.CreatedAt); err != nil {
			continue
		}
		orders = append(orders, o)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(orders)
}

func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(string)
	id := r.PathValue("id")

	var o Order
	err := h.db.QueryRow(
		`SELECT id, user_id, item, quantity, total, status, created_at FROM orders WHERE id = $1 AND user_id = $2`,
		id, userID,
	).Scan(&o.ID, &o.UserID, &o.Item, &o.Quantity, &o.Total, &o.Status, &o.CreatedAt)
	if err != nil {
		http.Error(w, `{"error":"order not found"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(o)
}
