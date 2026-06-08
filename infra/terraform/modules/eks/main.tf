# ============================================================================
# EKS Module
# ============================================================================
# Creates an EKS cluster with a managed node group.
#
# KEY DECISIONS:
# 1. Managed node group (not self-managed): AWS handles node updates, draining
# 2. IRSA (IAM Roles for Service Accounts): Pod-level AWS permissions
# 3. Private endpoint enabled: kubectl works from within VPC
# 4. Public endpoint enabled: kubectl works from your laptop (disable in prod)
# ============================================================================

# ---------------------------------------------------------------------------
# EKS Cluster IAM Role
# WHY: EKS control plane needs permissions to manage AWS resources (ENIs,
# security groups, logs). This role is assumed by the EKS service itself.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "cluster" {
  name = "${var.project}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

# WHY these policies: Minimum required for EKS control plane to function.
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# ---------------------------------------------------------------------------
# EKS Cluster
# WHY version pinned: Prevents surprise upgrades. You control when to upgrade.
# WHY both public+private endpoint: Public for dev access from laptop,
# private for pod-to-API communication. In prod, disable public.
# ---------------------------------------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = "${var.project}-${var.environment}"
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.cluster.id]
  }

  # WHY: Encrypts Kubernetes secrets at rest in etcd using your KMS key.
  # Without this, secrets are only base64-encoded (not encrypted).
  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  # WHY: Enables control plane logging for debugging and audit.
  # These logs go to CloudWatch. Enable what you need — each type costs money.
  enabled_cluster_log_types = ["api", "authenticator"]

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# ---------------------------------------------------------------------------
# Cluster Security Group
# WHY a dedicated SG: Controls what can talk to the EKS API server.
# Default allows all outbound (nodes need to reach AWS APIs).
# ---------------------------------------------------------------------------
resource "aws_security_group" "cluster" {
  name_prefix = "${var.project}-${var.environment}-eks-cluster-"
  vpc_id      = var.vpc_id
  description = "EKS cluster security group"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-eks-cluster-sg"
  }

  # WHY lifecycle: Prevents Terraform from destroying the SG while ENIs are
  # still attached (EKS creates ENIs in your subnets).
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Node Group IAM Role
# WHY separate from cluster role: Principle of least privilege.
# Nodes need different permissions than the control plane.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "nodes" {
  name = "${var.project}-${var.environment}-eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# WHY these 3 policies: Minimum for nodes to join cluster, pull images, and get IPs.
resource "aws_iam_role_policy_attachment" "nodes_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

# ---------------------------------------------------------------------------
# Launch Template for Node EBS Encryption
# WHY: Encrypts the root volume of every worker node with the account's
# default EBS encryption key (set by org policy/Control Tower).
# ---------------------------------------------------------------------------
resource "aws_launch_template" "nodes" {
  name_prefix = "${var.project}-${var.environment}-nodes-"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      # Use account default KMS key (required by org policy)
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project}-${var.environment}-node"
    }
  }
}

# ---------------------------------------------------------------------------
# Managed Node Group
# WHY managed: AWS handles AMI updates, node draining during upgrades.
# WHY t3.medium: 2 vCPU, 4GB RAM — enough for our 4 services + platform tools.
# WHY scaling 1-3: Starts with 2, scales up to 3 under load, down to 1 at night.
# ---------------------------------------------------------------------------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project}-${var.environment}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  instance_types = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # WHY: Ensures new nodes are ready before old ones are terminated during updates.
  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_cni,
    aws_iam_role_policy_attachment.nodes_ecr,
  ]
}

# ---------------------------------------------------------------------------
# OIDC Provider for IRSA (IAM Roles for Service Accounts)
# WHY: This is the magic that lets Kubernetes pods assume IAM roles.
# Without this, you'd attach permissions to the node role (too broad —
# every pod on the node gets the same AWS permissions).
# With IRSA: each pod gets only the permissions it needs.
# ---------------------------------------------------------------------------
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
