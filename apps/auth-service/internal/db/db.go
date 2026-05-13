package db

import (
	"database/sql"

	_ "github.com/lib/pq"
)

func Connect(databaseURL string) (*sql.DB, error) {
	if databaseURL == "" {
		databaseURL = "postgres://devuser:devpass@localhost:5432/devsecops?sslmode=disable"
	}

	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, err
	}

	if err := db.Ping(); err != nil {
		return nil, err
	}

	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)

	return db, nil
}
