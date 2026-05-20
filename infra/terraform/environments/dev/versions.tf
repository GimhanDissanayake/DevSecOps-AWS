# ============================================================================
# Version Constraints
# ============================================================================
# WHY pin versions:
# - required_version: Prevents running with an incompatible Terraform CLI
# - required_providers with ~>: Allows patch updates (bug fixes) but blocks
#   minor/major updates that could introduce breaking changes.
#   ~> 5.40 means >= 5.40.0 and < 6.0.0
# ============================================================================

terraform {
  required_version = ">= 1.10.0" # Minimum for S3 native locking

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
