# ============================================================================
# RDS Module — PostgreSQL
# ============================================================================
# WHY RDS over self-managed Postgres on EC2:
# - Automated backups, patching, failover
# - Multi-AZ with one toggle
# - Point-in-time recovery
# - You focus on your app, not database operations
#
# WHY PostgreSQL: Industry standard, rich feature set, great Go driver support.
# ============================================================================

# ---------------------------------------------------------------------------
# Subnet Group
# WHY: Tells RDS which subnets to place instances in.
# Must span at least 2 AZs for Multi-AZ deployments.
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project}-${var.environment}-db-subnet"
  }
}

# ---------------------------------------------------------------------------
# Security Group
# WHY: Only allow traffic from EKS nodes on port 5432.
# No public access — database is in private subnets with no internet route.
# ---------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name_prefix = "${var.project}-${var.environment}-rds-"
  vpc_id      = var.vpc_id
  description = "Allow PostgreSQL access from EKS nodes"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
    description     = "PostgreSQL from EKS nodes"
  }

  tags = {
    Name = "${var.project}-${var.environment}-rds-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# RDS Instance
# ---------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier = "${var.project}-${var.environment}-postgres"

  # Engine
  engine         = "postgres"
  engine_version = var.engine_version

  # Size — WHY db.t3.micro: Free tier eligible, sufficient for dev.
  # Production would use db.r6g.large or larger.
  instance_class = var.instance_class

  # Storage — WHY gp3: Better price/performance than gp2. No burst credits.
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage # Autoscaling
  storage_type          = "gp3"
  storage_encrypted     = true # WHY: Encryption at rest — always enable this.

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password # WHY variable: Never hardcode. Injected from secrets.

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # WHY: Database should NEVER be public.

  # High Availability
  # WHY multi_az: Automatic failover to standby in another AZ.
  # Doubles cost but provides <60s failover. Enable in prod.
  multi_az = var.multi_az

  # Backup
  # WHY 7 days: Allows point-in-time recovery to any second in the last week.
  # WHY backup window: Run during low-traffic hours.
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"

  # Maintenance
  # WHY maintenance window: Patches applied during this window.
  maintenance_window = "Mon:04:00-Mon:05:00"

  # WHY skip_final_snapshot false in prod: Prevents accidental data loss.
  # Set to true in dev to allow easy teardown.
  skip_final_snapshot       = var.environment == "dev"
  final_snapshot_identifier = var.environment != "dev" ? "${var.project}-${var.environment}-final" : null

  # WHY deletion_protection: Prevents terraform destroy from deleting the DB.
  # Must be manually disabled before destruction. Safety net.
  deletion_protection = var.environment == "prod"

  tags = {
    Name = "${var.project}-${var.environment}-postgres"
  }
}
