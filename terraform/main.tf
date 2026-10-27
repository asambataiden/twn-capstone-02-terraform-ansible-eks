data "aws_availability_zones" "available" { state = "available" }

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"
  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true
  public_subnet_tags = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"
  name = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  endpoint_public_access = true
  endpoint_public_access_cidrs = var.public_access_cidrs
  endpoint_private_access = true
  enable_cluster_creator_admin_permissions = true # Lab bootstrap only; replace with scoped access entries for production.
  addons = {
    coredns = {}
    eks-pod-identity-agent = { before_compute = true }
    kube-proxy = {}
    vpc-cni = { before_compute = true }
  }
  eks_managed_node_groups = {
    dev = {
      ami_type = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      min_size = 1
      max_size = 3
      desired_size = var.node_desired_size
    }
  }
  tags = { Environment = "learning", Application = "nginx" }
}
