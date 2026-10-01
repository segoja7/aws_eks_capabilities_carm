# Foundation Layer - Dev Environment
# VPC Configuration (region is us-east-1 — see common/common.hcl)
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnets     = ["10.0.10.0/24", "10.0.20.0/24"]
