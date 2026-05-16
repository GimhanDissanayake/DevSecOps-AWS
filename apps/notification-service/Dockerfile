FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /notification-service ./cmd/main.go

FROM gcr.io/distroless/static:nonroot

COPY --from=builder /notification-service /notification-service

EXPOSE 8083
USER nonroot:nonroot
ENTRYPOINT ["/notification-service"]
