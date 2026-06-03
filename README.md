# DevSecOps-AWS

A cloud-native microservices platform on AWS EKS demonstrating production-grade DevSecOps, Platform Engineering, and SRE practices.

## Architecture

```
Users → ALB → EKS Cluster (4 microservices) → RDS PostgreSQL / ElastiCache Redis
                    ↑
              ArgoCD (GitOps)
                    ↑
         GitHub Actions CI → ECR
```

Full architecture document: [docs/architecture.md](docs/architecture.md)

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Application | Go 1.22, REST APIs, JWT authentication |
| Containers | Docker (multi-stage, distroless runtime) |
| Orchestration | Kubernetes (AWS EKS) |
| Infrastructure | Terraform (modular, S3 native locking) |
| CI/CD | GitHub Actions (OIDC auth, Trivy scanning) |
| GitOps | ArgoCD (app-of-apps pattern) |
| Configuration | Ansible (SFTP server role) |
| Monitoring | Prometheus, Grafana, AlertManager |
| Security | Kyverno policies, Trivy CVE scanning |
| Database | PostgreSQL (RDS Multi-AZ), Redis (ElastiCache) |

## Microservices

| Service | Port | Purpose |
|---------|------|---------|
| auth-service | 8080 | JWT register/login/refresh/me |
| user-service | 8081 | User CRUD operations |
| order-service | 8082 | Order creation and listing |
| notification-service | 8083 | Async notifications via Redis queue |

## Quick Start (Local Development)

```bash
# Clone
git clone https://github.com/GimhanDissanayake/DevSecOps-AWS.git
cd DevSecOps-AWS

# Copy environment file
cp .env.example .env

# Start all services
docker compose up --build

# Test
curl localhost:8080/health
curl -X POST localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"secret123","name":"Test User"}'
```

## Project Structure

```
├── apps/                       # Go microservices
│   ├── auth-service/
│   ├── user-service/
│   ├── order-service/
│   └── notification-service/
├── infra/terraform/            # Infrastructure as Code
│   ├── modules/                # Reusable: vpc, eks, rds, elasticache, ecr, ec2-sftp
│   └── environments/           # dev + prod compositions
├── helm/                       # Kubernetes deployment
│   ├── charts/                 # One chart per service
│   └── values/                 # Environment overrides
├── gitops/                     # ArgoCD manifests
│   ├── appsets/root.yaml       # App-of-apps root
│   └── applications/           # Per-service Applications
├── .github/workflows/          # CI/CD pipelines
├── ansible/                    # EC2 configuration management
├── monitoring/                 # Prometheus rules, Grafana dashboards
├── security/                   # Kyverno policies, Trivy config
├── scripts/                    # Utility scripts
└── docs/                       # Architecture, learning guides
```

## Deployment Flow

```
1. Developer pushes to main
2. GitHub Actions: lint → test → build → scan → push to ECR
3. ArgoCD detects new image tag in Git
4. ArgoCD deploys updated Helm chart to EKS
5. Kyverno validates pod security compliance
6. Prometheus scrapes metrics, alerts if SLOs breached
```

## Infrastructure (Terraform)

Modules follow AWS Well-Architected Framework:

| Module | What It Creates |
|--------|----------------|
| vpc | Multi-AZ VPC, public/private subnets, NAT gateway |
| eks | EKS cluster, managed node group, IRSA (OIDC) |
| rds | PostgreSQL Multi-AZ, encrypted, automated backups |
| elasticache | Redis with conditional failover |
| ecr | Container registries with lifecycle policies |
| ec2-sftp | Ubuntu instance for Ansible configuration |

```bash
cd infra/terraform/environments/dev
terraform init
terraform plan
terraform apply
```

## CI/CD Pipeline

| Stage | Tool | Purpose |
|-------|------|---------|
| Lint | golangci-lint | Code quality |
| Test | go test | Unit tests |
| Build | Docker | Multi-stage container build |
| Scan | Trivy | CVE detection (fails on HIGH/CRITICAL) |
| Push | ECR | Private container registry |
| Deploy | ArgoCD | GitOps sync to EKS |

Authentication: GitHub OIDC → AWS (no stored credentials).

## Monitoring

- **Alerts**: Error rate > 5%, P99 latency > 1s, pod restart loops, memory > 85%
- **Dashboards**: Request rate, error rate, latency per service (Grafana)
- **Method**: RED (Rate, Errors, Duration) for services

## Security

| Layer | Tool | Enforcement |
|-------|------|-------------|
| CI | Trivy | Block images with HIGH/CRITICAL CVEs |
| Admission | Kyverno | Enforce non-root, no privilege escalation, require resource limits |
| Runtime | Pod Security Context | readOnlyRootFilesystem, runAsNonRoot |
| Network | Security Groups | Least-privilege (EKS → RDS only on 5432) |
| Secrets | External Secrets Operator | AWS Secrets Manager → K8s Secrets |
| Auth | IRSA | Pod-level IAM roles (not node-level) |

## Documentation

| Document | Location |
|----------|----------|
| Architecture & Roadmap | [docs/architecture.md](docs/architecture.md) |
| Learning Guide | [docs/learning-guide.md](docs/learning-guide.md) |
| Conventional Commits | [docs/conventional-commits.md](docs/conventional-commits.md) |
| Git Guide | [docs/git-guide.md](docs/git-guide.md) |
| Secret Incident Runbook | [docs/secret-incident-runbook.md](docs/secret-incident-runbook.md) |
| GitHub Repo Setup | [docs/github-repo-setup.md](docs/github-repo-setup.md) |
| ADR: Monorepo | [docs/adr/001-monorepo.md](docs/adr/001-monorepo.md) |

## Prerequisites

- Go 1.22+
- Docker & Docker Compose
- Terraform >= 1.10
- AWS CLI configured
- kubectl
- Helm 3
- gh (GitHub CLI)
