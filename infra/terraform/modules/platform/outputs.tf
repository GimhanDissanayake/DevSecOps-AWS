output "argocd_namespace" {
  value = helm_release.argocd.namespace
}

output "monitoring_namespace" {
  value = helm_release.prometheus_stack.namespace
}
