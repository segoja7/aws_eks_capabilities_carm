include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("common/common.hcl"))
}

# Cross-account dependency: reads the CENTRAL account's own remote state (its own
# backend/profile, independent of this stack's spoke credentials) for the ACK
# capability role ARN. Terragrunt resolves `dependency` outputs by running
# `terraform output` against the dependency's OWN generated backend — the account
# boundary is transparent to it. Applying `run --all` from the repo root builds
# central first (this unit depends on it), then this trust role, in one pass.
dependency "ack" {
  config_path = "../../../../stacks/platform/containers/eks"

  mock_outputs = {
    ack_role_arn = "arn:aws:iam::700922282251:role/mock-ack-capability-role"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
}

inputs = {
  project           = local.environment_vars.locals.project
  trusted_role_arn  = dependency.ack.outputs.ack_role_arn

  tags = {
    ProjectCode = local.environment_vars.locals.project
    Framework   = "DevSecOps-IaC"
    Account     = "spoke"
    Layer       = "carm-trust"
  }
}
