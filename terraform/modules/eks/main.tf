###############################################################################
# EKS cluster using the official terraform-aws-modules/eks module.
# Managed node group runs in private subnets. IRSA enabled so workloads can
# assume IAM roles (used by the AWS Load Balancer Controller, etc.).
###############################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  enable_irsa = true

  # Grant the Terraform caller admin on the cluster so kubectl/argocd work.
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      instance_types = var.instance_types
      capacity_type  = var.capacity_type
      desired_size   = var.desired_size
      min_size       = var.min_size
      max_size       = var.max_size
      subnet_ids     = var.private_subnet_ids
    }
  }

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  tags = var.tags
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

# SG attached to the managed nodes — RDS allows ingress from this.
output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}
