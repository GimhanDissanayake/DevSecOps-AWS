terraform {
  backend "s3" {
    bucket       = "devsecops-aws-tfstate"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
