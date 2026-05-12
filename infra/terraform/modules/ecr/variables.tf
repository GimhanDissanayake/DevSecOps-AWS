variable "project" {
  type = string
}

variable "services" {
  type    = list(string)
  default = ["auth-service", "user-service", "order-service", "notification-service"]
}
