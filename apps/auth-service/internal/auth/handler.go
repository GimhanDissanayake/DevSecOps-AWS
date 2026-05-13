package auth

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

type Handler struct {
	db        *sql.DB
	jwtSecret []byte
}

func NewHandler(db *sql.DB, secret string) *Handler {
	return &Handler{db: db, jwtSecret: []byte(secret)}
}

type registerRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	Name     string `json:"name"`
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type tokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
}

func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.Email == "" || req.Password == "" || req.Name == "" {
		http.Error(w, `{"error":"email, password, and name are required"}`, http.StatusBadRequest)
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		http.Error(w, `{"error":"internal error"}`, http.StatusInternalServerError)
		return
	}

	var id string
	err = h.db.QueryRow(
		`INSERT INTO users (email, password_hash, name) VALUES ($1, $2, $3) RETURNING id`,
		req.Email, string(hash), req.Name,
	).Scan(&id)
	if err != nil {
		http.Error(w, `{"error":"email already exists"}`, http.StatusConflict)
		return
	}

	tokens, err := h.generateTokens(id, req.Email)
	if err != nil {
		http.Error(w, `{"error":"internal error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(tokens)
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	var id, hash string
	err := h.db.QueryRow(
		`SELECT id, password_hash FROM users WHERE email = $1`, req.Email,
	).Scan(&id, &hash)
	if err != nil {
		http.Error(w, `{"error":"invalid credentials"}`, http.StatusUnauthorized)
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)); err != nil {
		http.Error(w, `{"error":"invalid credentials"}`, http.StatusUnauthorized)
		return
	}

	tokens, err := h.generateTokens(id, req.Email)
	if err != nil {
		http.Error(w, `{"error":"internal error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tokens)
}

func (h *Handler) Refresh(w http.ResponseWriter, r *http.Request) {
	var body struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	claims := &jwt.RegisteredClaims{}
	token, err := jwt.ParseWithClaims(body.RefreshToken, claims, func(t *jwt.Token) (interface{}, error) {
		return h.jwtSecret, nil
	})
	if err != nil || !token.Valid {
		http.Error(w, `{"error":"invalid refresh token"}`, http.StatusUnauthorized)
		return
	}

	tokens, err := h.generateTokens(claims.Subject, claims.Issuer)
	if err != nil {
		http.Error(w, `{"error":"internal error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tokens)
}

func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(string)

	var email, name string
	err := h.db.QueryRow(
		`SELECT email, name FROM users WHERE id = $1`, userID,
	).Scan(&email, &name)
	if err != nil {
		http.Error(w, `{"error":"user not found"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"id": userID, "email": email, "name": name,
	})
}

func (h *Handler) generateTokens(userID, email string) (*tokenResponse, error) {
	now := time.Now()

	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, &jwt.RegisteredClaims{
		Subject:   userID,
		Issuer:    email,
		ExpiresAt: jwt.NewNumericDate(now.Add(15 * time.Minute)),
		IssuedAt:  jwt.NewNumericDate(now),
	})
	access, err := accessToken.SignedString(h.jwtSecret)
	if err != nil {
		return nil, err
	}

	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, &jwt.RegisteredClaims{
		Subject:   userID,
		Issuer:    email,
		ExpiresAt: jwt.NewNumericDate(now.Add(7 * 24 * time.Hour)),
		IssuedAt:  jwt.NewNumericDate(now),
	})
	refresh, err := refreshToken.SignedString(h.jwtSecret)
	if err != nil {
		return nil, err
	}

	return &tokenResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		ExpiresIn:    900,
	}, nil
}
