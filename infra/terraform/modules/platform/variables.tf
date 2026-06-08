variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.7.0"
}

variable "kyverno_version" {
  description = "Kyverno Helm chart version"
  type        = string
  default     = "3.3.4"
}

variable "prometheus_stack_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = "65.3.1"
}
