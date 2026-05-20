# ============================================================================
# Prod Environment — Resource Composition
# ============================================================================
# Differences from dev:
# - RDS: Multi-AZ, larger instance, deletion protection, 14-day backups
# - EKS: More nodes, larger instances
# - ElastiCache: 2 nodes with automatic failover
# - No SFTP server (dev-only for Ansible practice)
# - Different VPC CIDR (enables VPC peering between environments if needed)
# ============================================================================

locals {
  project     = "devsecops-aws"
  environment = "prod"
}

module "vpc" {
  source = "../../modules/vpc"

  project              = local.project
  environment          = local.environment
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
}

module "eks" {
  source = "../../modules/eks"

  project            = local.project
  environment        = local.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  cluster_version    = "1.29"
  node_instance_type = "t3.large"
  node_desired_size  = 3
  node_min_size      = 2
  node_max_size      = 5
}

module "rds" {
  source = "../../modules/rds"

  project                    = local.project
  environment                = local.environment
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  eks_node_security_group_id = module.eks.cluster_security_group_id
  instance_class             = "db.t3.medium"
  multi_az                   = true
  backup_retention_days      = 14
  db_password                = var.db_password
}

module "elasticache" {
  source = "../../modules/elasticache"

  project                    = local.project
  environment                = local.environment
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  eks_node_security_group_id = module.eks.cluster_security_group_id
  node_type                  = "cache.t3.small"
  num_cache_nodes            = 2
}

module "ecr" {
  source = "../../modules/ecr"

  project = local.project
}
