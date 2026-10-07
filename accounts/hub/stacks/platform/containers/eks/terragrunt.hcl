include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "account" {
  path = find_in_parent_folders("account.hcl")
}

include "provider_aws" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/common/additional_providers/provider_aws.hcl"
}

dependency "vpc" {
  config_path = "../../../foundation/network/vpc"

  mock_outputs = {
    vpc_id          = "vpc-123456"
    private_subnets = ["subnet-123456a", "subnet-123456b"]
    public_subnets  = ["subnet-123456c", "subnet-123456d"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# For the manifests-verifier Pod Identity role's ECR read scope (Frontier 2's
# PreSync-hook double-check — notation verify, running inside the cluster).
dependency "ecr" {
  config_path = "../../containers/ecr"

  mock_outputs = {
    repository_arns = ["arn:aws:ecr:us-east-1:000000000000:repository/kcl-modules/mock"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  # The spoke names its CARM role from its own project; read that same value here so
  # the hub's trust never drifts from the role the spoke actually creates.
  spoke_account_vars = read_terragrunt_config("${dirname(find_in_parent_folders("root.hcl"))}/accounts/spoke/account.hcl")
  common       = read_terragrunt_config(find_in_parent_folders("common/common.hcl"))
  project      = local.account_vars.locals.project
  env          = local.common.locals.environment
}

inputs = {
  spoke_carm_role_name = "${local.spoke_account_vars.locals.project}-ack-carm-trust"

  project     = local.project
  environment = local.env

  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnets

  ecr_repository_arns = dependency.ecr.outputs.repository_arns

  tags = {
    ProjectCode = local.project
    Framework   = "DevSecOps-IaC"
    Environment = local.env
    ManagedBy   = "terragrunt"
    Layer       = "platform"
    Domain      = "containers"
  }
}
