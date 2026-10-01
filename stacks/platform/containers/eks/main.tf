module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.0"

  name               = "${var.project}-${var.environment}-mgmt"
  kubernetes_version = var.cluster_version

  endpoint_public_access  = true
  endpoint_private_access = true

  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = { before_compute = true }
    eks-pod-identity-agent = { before_compute = true }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "BOTTLEROCKET_x86_64"
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
    }
  }

  tags = var.tags
}
