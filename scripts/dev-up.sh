#!/usr/bin/env bash
set -euo pipefail

# Local development setup script
echo "Starting local development environment..."

docker compose up -d

echo "Services:"
echo "  auth-service:         http://localhost:8080"
echo "  user-service:         http://localhost:8081"
echo "  order-service:        http://localhost:8082"
echo "  notification-service: http://localhost:8083"
