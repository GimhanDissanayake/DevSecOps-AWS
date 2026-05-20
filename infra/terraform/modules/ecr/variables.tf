variable "project" {
  description = "Project name (used as ECR namespace)"
  type        = string
}

variable "services" {
  description = "List of microservice names to create repos for"
  type        = list(string)
  default     = ["auth-service", "user-service", "order-service", "notification-service"]
}
