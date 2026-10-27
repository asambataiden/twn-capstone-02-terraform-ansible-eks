provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  default_tags { tags = { Project = "twn-capstone-02", ManagedBy = "terraform", Environment = "learning" } }
}
