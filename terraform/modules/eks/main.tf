module "eks" {

  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id = var.vpc_id

  subnet_ids = var.subnet_ids

  endpoint_public_access = true

  enable_irsa = true

  enable_cluster_creator_admin_permissions = true

  addons = {

    coredns = {}

    kube-proxy = {}

    vpc-cni = {
      most_recent = true
    }

    eks-pod-identity-agent = {}
  }

  eks_managed_node_groups = {

    workers = {

      instance_types = [
        "c7i-flex.large"
      ]

      min_size     = 2
      max_size     = 4
      desired_size = 2

      disk_size = 30

      capacity_type = "ON_DEMAND"

      labels = {
        role = "worker"
      }

      tags = {
        Name        = "${var.cluster_name}-workers"
        Environment = var.environment
      }
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Terraform   = "true"
  }
}