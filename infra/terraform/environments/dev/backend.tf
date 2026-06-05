# ============================================================================
# Backend Configuration
# ============================================================================
# WHY S3 backend: Remote state enables team collaboration.
# WHY use_lockfile (not dynamodb_table): Terraform 1.10+ supports native S3
# locking via S3 Object Lock. DynamoDB-based locking is DEPRECATED and will
# be removed in a future version. Native locking is simpler (one fewer AWS
# resource) and cheaper.
#
# PREREQUISITE: The S3 bucket must be created with Object Lock enabled:
#   aws s3api create-bucket --bucket devsecops-aws-tfstate \
#     --region us-east-1 --object-lock-enabled-for-bucket
#   aws s3api put-bucket-versioning --bucket devsecops-aws-tfstate \
#     --versioning-configuration Status=Enabled
# ============================================================================

terraform {
  backend "s3" {
    bucket       = "test-devsecops-aws-tfstate"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # S3 native locking — no DynamoDB needed
  }
}
