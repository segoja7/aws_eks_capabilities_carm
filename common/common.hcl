# Transversal shared config for ALL accounts. Per-account values (profile,
# project, project_folder, account id/name, tags) live in accounts/<name>/account.hcl.
# No `generate "provider"` here — that moved to common/additional_providers/provider_aws.hcl.
locals {
  deployment_region = "us-east-1"
  environment       = get_env("TF_VAR_ENVIRONMENT", "dev")

  # Backend is centralized in the HUB account for governance; identical for
  # every account (only the project_folder prefix in account.hcl differs).
  backend_region        = "us-east-1"
  backend_bucket_name   = "base-eks-tfstate-700922282251"
  backend_profile       = "segoja7-hub"
  backend_dynamodb_lock = "db-terraform-lock-700922282251"
  backend_key           = "terraform.tfstate"
  backend_encrypt       = true
}
