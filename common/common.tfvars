# Transversal shared tfvars for ALL accounts. Per-account values (project, profile)
# are NOT set here: `project` is supplied per-stack via Terragrunt inputs from
# accounts/<name>/account.hcl, and `profile` comes from the per-account default in
# the generated provider.tf (common/additional_providers/provider_aws.hcl). Setting
# them here as a -var-file would override the per-account values and make the spoke
# authenticate against the hub.
environment = "dev"
owner = "segoja7"
region = "us-east-1"

required_tags = {
  Project = "base-eks",
  Environment = "dev",
  Owner = "segoja7",
  ManagedBy = "Tofu-Terragrunt"
}