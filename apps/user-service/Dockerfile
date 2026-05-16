FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /user-service ./cmd/main.go

FROM gcr.io/distroless/static:nonroot

COPY --from=builder /user-service /user-service

EXPOSE 8081
USER nonroot:nonroot
ENTRYPOINT ["/user-service"]
