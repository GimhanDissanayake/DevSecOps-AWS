# ============================================================================
# ElastiCache Module — Redis
# ============================================================================
# WHY ElastiCache over self-managed Redis:
# - Managed patching, failover, backups
# - Cluster mode for horizontal scaling (not needed yet)
# WHY Redis over Memcached:
# - Persistence, pub/sub, data structures (lists for our notification queue)
# ============================================================================

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-redis-subnet"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "redis" {
  name_prefix = "${var.project}-${var.environment}-redis-"
  vpc_id      = var.vpc_id
  description = "Allow Redis access from EKS nodes"

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
    description     = "Redis from EKS nodes"
  }

  tags = {
    Name = "${var.project}-${var.environment}-redis-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# WHY replication group over single cache cluster:
# - Supports automatic failover (even with 1 replica)
# - Can add read replicas later without recreation
resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project}-${var.environment}-redis"
  description          = "Redis for ${var.project} ${var.environment}"

  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_nodes
  port                 = 6379
  engine_version       = "7.1"
  parameter_group_name = "default.redis7"

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  # WHY at_rest + in_transit encryption: Defense in depth.
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false # WHY false: Adds latency. Enable in prod with TLS.

  # WHY automatic failover disabled for single node:
  # Requires 2+ nodes. Enable when num_cache_nodes > 1.
  automatic_failover_enabled = var.num_cache_nodes > 1

  tags = {
    Name = "${var.project}-${var.environment}-redis"
  }
}
