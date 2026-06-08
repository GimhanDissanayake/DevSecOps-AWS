# ============================================================================
# Dev Environment — Resource Composition
# ============================================================================
# This file ONLY composes modules. Configuration is separated:
# - versions.tf  → Terraform and provider version constraints
# - providers.tf → Provider configuration (region, default_tags)
# - backend.tf   → State storage configuration
# - variables.tf → Input variables
# - outputs.tf   → Output values
#
# WHY this separation:
# - Each file has a single responsibility
# - Easy to find what you're looking for
# - Diff-friendly (changing a provider version doesn't touch resource code)
# - Industry standard (what reviewers expect to see)
# ============================================================================

locals {
  project     = "devsecops-aws"
  environment = "dev"
}

# ---------------------------------------------------------------------------
# KMS Key — Shared encryption key for all resources in this environment
# WHY one key per environment:
# - Single audit trail for all encryption/decryption operations
# - One rotation policy to manage
# - Easy to grant access via key policy
# - Cost: $1/month per key (negligible)
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

resource "aws_kms_key" "main" {
  description             = "Encryption key for ${local.project} ${local.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true # WHY: Automatic annual rotation — security best practice

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowEKSNodeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.project}-${local.environment}-eks-nodes-role"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEKSClusterRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.project}-${local.environment}-eks-cluster-role"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${local.project}-${local.environment}-key"
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.project}-${local.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  project     = local.project
  environment = local.environment
  vpc_cidr    = "10.0.0.0/16"
}

# ---------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------
module "eks" {
  source = "../../modules/eks"

  project            = local.project
  environment        = local.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  cluster_version    = "1.36"
  node_instance_type = "t3.medium"
  node_desired_size  = 2
  node_min_size      = 2
  node_max_size      = 3
  kms_key_arn        = aws_kms_key.main.arn
}

# ---------------------------------------------------------------------------
# RDS — Single-AZ in dev (saves ~$15/month vs multi-AZ)
# ---------------------------------------------------------------------------
module "rds" {
  source = "../../modules/rds"

  project                    = local.project
  environment                = local.environment
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  eks_node_security_group_id = module.eks.cluster_security_group_id
  instance_class             = "db.t3.micro"
  multi_az                   = false
  db_password                = var.db_password
  kms_key_arn                = aws_kms_key.main.arn
}

# ---------------------------------------------------------------------------
# ElastiCache — Single node in dev (no failover needed)
# ---------------------------------------------------------------------------
module "elasticache" {
  source = "../../modules/elasticache"

  project                    = local.project
  environment                = local.environment
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  eks_node_security_group_id = module.eks.cluster_security_group_id
  node_type                  = "cache.t3.micro"
  num_cache_nodes            = 1
}

# ---------------------------------------------------------------------------
# ECR — Container registries (shared across environments)
# ---------------------------------------------------------------------------
module "ecr" {
  source = "../../modules/ecr"

  project = local.project
}

# ---------------------------------------------------------------------------
# EC2 SFTP — For Ansible configuration practice
# ---------------------------------------------------------------------------
module "sftp" {
  source = "../../modules/ec2-sftp"

  project           = local.project
  environment       = local.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_ids[0]
  ssh_public_key    = var.ssh_public_key
  allowed_ssh_cidrs = [var.my_ip]
}

# ---------------------------------------------------------------------------
# Platform Tools — ArgoCD, Kyverno, Prometheus/Grafana
# WHY here (not separate state): These are integral to the cluster.
# If the cluster is destroyed, the tools go with it. Same lifecycle.
# ---------------------------------------------------------------------------
module "platform" {
  source = "../../modules/platform"

  depends_on = [module.eks]
}
