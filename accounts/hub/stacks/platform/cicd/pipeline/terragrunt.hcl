include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "account" {
  path = find_in_parent_folders("account.hcl")
}

include "provider_aws" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/common/additional_providers/provider_aws.hcl"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  common       = read_terragrunt_config(find_in_parent_folders("common/common.hcl"))
  project      = local.account_vars.locals.project
  env          = local.common.locals.environment
}


dependency "eks" {
  config_path = "../../containers/eks"

  mock_outputs = {
    argocd_role_arn                = "arn:aws:iam::123456789012:role/mock-argocd"
    manifests_verifier_role_arn    = "arn:aws:iam::123456789012:role/mock-verifier"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "claims_repo" {
  config_path = "../claims-repo"

  mock_outputs = {
    claims_repo_url = "https://git-codecommit.us-east-1.amazonaws.com/v1/repos/mock-claims"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "ecr" {
  config_path = "../../containers/ecr"

  mock_outputs = {
    registry_url        = "123456789012.dkr.ecr.us-east-1.amazonaws.com"
    namespace           = "kcl-modules"
    repository_arns     = ["arn:aws:ecr:us-east-1:123456789012:repository/kcl-modules/mock"]
    manifests_url       = "123456789012.dkr.ecr.us-east-1.amazonaws.com/kcl-modules/manifests"
    signing_profile_arn = "arn:aws:signer:us-east-1:123456789012:/signing-profiles/platform_mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  project     = local.project
  environment = local.env

  ecr_registry        = dependency.ecr.outputs.registry_url
  ecr_namespace       = dependency.ecr.outputs.namespace
  ecr_repository_arns = dependency.ecr.outputs.repository_arns
  ecr_read_principal_arns = [
    dependency.eks.outputs.argocd_role_arn,
    dependency.eks.outputs.manifests_verifier_role_arn,
  ]
  ecr_manifests_url   = dependency.ecr.outputs.manifests_url
  signing_profile_arn = dependency.ecr.outputs.signing_profile_arn
  claims_repo_url     = dependency.claims_repo.outputs.claims_repo_url

  tags = {
    ProjectCode = local.project
    Framework   = "DevSecOps-IaC"
    Environment = local.env
    ManagedBy   = "terragrunt"
    Layer       = "platform"
    Domain      = "cicd"
  }
}
