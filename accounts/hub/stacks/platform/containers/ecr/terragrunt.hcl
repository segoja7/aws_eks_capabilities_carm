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

inputs = {
  project     = local.project
  environment = local.env

  tags = {
    ProjectCode = local.project
    Framework   = "DevSecOps-IaC"
    Environment = local.env
    ManagedBy   = "terragrunt"
    Layer       = "platform"
    Domain      = "containers"
  }
}
