# Hub / central account (700922282251) — Organizations management account.
# The ONLY per-account divergence. Everything else (backend, provider shape,
# extra_arguments, tfvars loading) is transversal in root.hcl / common/.
locals {
  account_name = "hub"
  account_id   = "700922282251"
  profile      = "segoja7-hub"
  region       = "us-east-1"
  project      = "base-eks"
  # format: cloud_provider/client/project — drives the state key prefix.
  project_folder = "aws/dev-to/base-eks"

  tags = {
    ProjectCode = "base-eks"
    Framework   = "DevSecOps-IaC"
    Account     = "hub"
  }
}
