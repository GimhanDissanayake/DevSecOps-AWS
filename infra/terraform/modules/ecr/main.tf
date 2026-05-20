# ============================================================================
# ECR Module — Container Registry
# ============================================================================
# WHY ECR over Docker Hub:
# - Private by default (no accidental public images)
# - Integrated with EKS (no separate auth needed with IRSA)
# - Image scanning built-in
# - Same AWS account = no cross-account pull latency
# ============================================================================

# WHY for_each over count: for_each gives you named resources in state
# (aws_ecr_repository.main["auth-service"]) instead of indexed ones
# (aws_ecr_repository.main[0]). Easier to manage, won't reorder on changes.
resource "aws_ecr_repository" "main" {
  for_each = toset(var.services)

  name                 = "${var.project}/${each.key}"
  image_tag_mutability = "IMMUTABLE" # WHY: Prevents overwriting tags. Forces unique tags per build.

  # WHY: Scans images for CVEs on push. Free for basic scanning.
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = each.key
    Service = each.key
  }
}

# ---------------------------------------------------------------------------
# Lifecycle Policy
# WHY: Without this, ECR accumulates images forever (costs money).
# This keeps the last 20 tagged images and removes untagged after 1 day.
# ---------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "main" {
  for_each = aws_ecr_repository.main

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only last 20 tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v", "sha-"]
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
