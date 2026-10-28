# Activate only AFTER bootstrap-state bucket exists and is approved.
# Copy this file to backend.tf, then run terraform init -reconfigure
# from terraform/ BEFORE any workload terraform apply.
terraform {
  backend "s3" {
    bucket       = "twn-capstone02-tfstate-591132357918-eu-north-1"
    key          = "capstone02/eks/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}
