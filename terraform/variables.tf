variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "aws_account_id" {
  type        = string
  description = "Approved 12-digit AWS account ID."
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Supply a 12-digit AWS account ID."
  }
}

variable "cluster_name" {
  type    = string
  default = "myapp-eks-cluster"
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.42.0.0/20", "10.42.16.0/20"]
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.42.32.0/20", "10.42.48.0/20"]
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "Trusted EKS public endpoint CIDRs; never 0.0.0.0/0."
  validation {
    condition     = length(var.public_access_cidrs) > 0 && alltrue([for c in var.public_access_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "Provide at least one trusted CIDR without 0.0.0.0/0."
  }
}
