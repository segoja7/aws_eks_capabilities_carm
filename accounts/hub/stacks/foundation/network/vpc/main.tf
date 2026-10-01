
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = "${var.project}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs = var.availability_zones

  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  # EKS load balancer auto-discovery: internet-facing LBs land in public
  # subnets, internal ones in private.
  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }

  enable_nat_gateway = true
  single_nat_gateway = true

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.tags
}