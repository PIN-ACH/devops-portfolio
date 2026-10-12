###############################################################################
# Root configuration for the "dev" environment.
# Wires together VPC -> ECR -> EKS -> RDS -> IAM -> Jenkins EC2.
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Remote state is strongly recommended. Uncomment and create the bucket +
  # DynamoDB table first (see scripts/bootstrap-backend.sh), then run
  # `terraform init -migrate-state`.
  #
  # backend "s3" {
  #   bucket         = "CHANGE-ME-tfstate-bucket"
  #   key            = "devops-portfolio/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "CHANGE-ME-tf-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

locals {
  name = "${var.project}-${var.environment}"
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source       = "../../modules/vpc"
  name         = local.name
  vpc_cidr     = var.vpc_cidr
  cluster_name = local.name
  tags         = local.tags
}

module "ecr" {
  source = "../../modules/ecr"
  name   = var.project
  tags   = local.tags
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = local.name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  instance_types     = var.node_instance_types
  capacity_type      = var.node_capacity_type
  desired_size       = var.node_desired_size
  min_size           = var.node_min_size
  max_size           = var.node_max_size
  tags               = local.tags
}

module "rds" {
  source                     = "../../modules/rds"
  name                       = local.name
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  instance_class             = var.db_instance_class
  allowed_security_group_ids = [module.eks.node_security_group_id]
  tags                       = local.tags
}

# Allow Jenkins to reach RDS, added as a standalone rule to avoid a module
# dependency cycle (rds -> jenkins -> iam -> rds).
resource "aws_security_group_rule" "db_from_jenkins" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = module.rds.security_group_id
  source_security_group_id = module.ec2_jenkins.security_group_id
  description              = "MySQL from Jenkins"
}

module "iam" {
  source             = "../../modules/iam"
  name               = local.name
  ecr_repository_arn = module.ecr.repository_arn
  db_secret_arn      = module.rds.secret_arn
  tags               = local.tags
}

module "ec2_jenkins" {
  source                = "../../modules/ec2-jenkins"
  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  public_subnet_id      = module.vpc.public_subnet_ids[0]
  instance_type         = var.jenkins_instance_type
  key_name              = var.key_name
  allowed_ssh_cidr      = var.allowed_ssh_cidr
  instance_profile_name = module.iam.jenkins_instance_profile_name
  tags                  = local.tags
}

# Grant the Jenkins IAM role admin access inside the cluster so the pipeline
# can run kubectl/argocd. Scope this down in a real production setup.
resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.iam.jenkins_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jenkins" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.iam.jenkins_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}
