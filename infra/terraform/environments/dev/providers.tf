# ============================================================================
# Provider Configuration
# ============================================================================
# WHY default_tags: Every resource gets these tags automatically.
# No more forgetting to tag resources. Essential for:
# - Cost allocation (which project/env is spending money?)
# - Automation (find all resources for an environment)
# - Compliance (who manages this resource?)
# ============================================================================

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = local.project
      Environment = local.environment
      ManagedBy   = "terraform"
    }
  }
}
