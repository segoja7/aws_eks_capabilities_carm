# Spoke / workload account (570903461087) in the same AWS Organization.
# Only per-account divergence. Backend stays the HUB's bucket/table/profile
# (centralized state), set transversally in common/common.hcl.
locals {
  account_name   = "spoke"
  account_id     = "570903461087"
  profile        = "segoja7-spoke1"
  region         = "us-east-1"
  project        = "base-eks-spoke1"
  project_folder = "aws/dev-to/base-eks-spoke1"

  tags = {
    ProjectCode = "base-eks-spoke1"
    Framework   = "DevSecOps-IaC"
    Account     = "spoke"
  }
}
