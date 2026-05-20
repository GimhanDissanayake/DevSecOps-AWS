# WHY versions.tf in modules: Declares which providers this module requires.
# The calling environment provides the actual provider configuration.
# This prevents "implicit provider" warnings and makes dependencies explicit.

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
