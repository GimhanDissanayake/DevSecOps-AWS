# ============================================================================
# Platform Module — Cluster Tools
# ============================================================================
# Installs platform services on EKS via Helm.
# WHY Terraform helm_release over kubectl apply:
# - Version pinned and state-tracked
# - Part of the same terraform apply workflow
# - Idempotent — team doesn't need separate scripts
# - Upgradeable via terraform plan/apply
# ============================================================================

# ---------------------------------------------------------------------------
# ArgoCD — GitOps Controller
# WHY ArgoCD: Watches Git for desired state, reconciles cluster to match.
# Single source of truth for all deployments.
# ---------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = "argocd"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  # WHY: Disable insecure flag in prod. For dev, we access via port-forward.
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }
}

# ---------------------------------------------------------------------------
# Kyverno — Policy Engine
# WHY Kyverno over OPA/Gatekeeper: Kubernetes-native (uses CRDs, not Rego),
# easier to write policies, supports validate + mutate + generate.
# ---------------------------------------------------------------------------
resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno"
  chart            = "kyverno"
  version          = var.kyverno_version
  namespace        = "kyverno"
  create_namespace = true
}

# ---------------------------------------------------------------------------
# kube-prometheus-stack — Monitoring
# WHY this chart: Installs Prometheus, Grafana, Alertmanager, node-exporter,
# kube-state-metrics, and default dashboards in one chart.
# ---------------------------------------------------------------------------
resource "helm_release" "prometheus_stack" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.prometheus_stack_version
  namespace        = "monitoring"
  create_namespace = true

  # WHY: Grafana admin password — should be overridden via variables in prod
  set_sensitive {
    name  = "grafana.adminPassword"
    value = "admin"
  }

  # WHY: Enable Grafana dashboard sidecar to pick up ConfigMaps
  set {
    name  = "grafana.sidecar.dashboards.enabled"
    value = "true"
  }

  set {
    name  = "grafana.sidecar.dashboards.label"
    value = "grafana_dashboard"
  }
}
