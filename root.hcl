# SINGLE transversal root for every account tree (accounts/<name>/**).
# Per-account values come from accounts/<name>/account.hcl, discovered by each
# stack via `include "account"`. Shared values come from common/common.hcl.
locals {
  common_vars  = read_terragrunt_config("${get_parent_terragrunt_dir()}/common/common.hcl")
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Downward path from the account root dir (where account.hcl lives) to the
  # current stack dir — e.g. "stacks/platform/containers/eks". We can't use
  # path_relative_to_include("account") here: this remote_state block lives in
  # root.hcl (an included parent), and the named-include lookup only resolves
  # includes declared in THIS file — root.hcl has none, so it would fall back to
  # the repo-root anchor and prepend "accounts/<name>/". get_terragrunt_dir() and
  # find_in_parent_folders() both evaluate against the child unit, so trimming the
  # account dir prefix yields the correct per-account-relative stack path.
  account_root      = dirname(find_in_parent_folders("account.hcl"))
  stack_rel_to_acct = trimprefix(get_terragrunt_dir(), "${local.account_root}/")
}

inputs = {
  COMMAND        = get_terraform_cli_args()
  COMMAND_GLOBAL = local.common_vars.locals
}

terraform {
  extra_arguments "init_arg" {
    commands = ["init"]
    arguments = [
      "-reconfigure"
    ]
    env_vars = {
      TERRAGRUNT_AUTO_INIT = true
    }
  }

  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()

    arguments = [
      "-var-file=${get_parent_terragrunt_dir()}/common/common.tfvars"
    ]
    optional_var_files = [
      ## overwrite to use in pipeline setup is created by ci job
      "${get_parent_terragrunt_dir()}/overwrite.auto.tfvars",

      "${get_parent_terragrunt_dir()}/accounts/hub/environments/${get_env("TF_VAR_ENVIRONMENT", "dev")}/applications.tfvars",
      "${get_parent_terragrunt_dir()}/accounts/hub/environments/${get_env("TF_VAR_ENVIRONMENT", "dev")}/foundations.tfvars",
      "${get_parent_terragrunt_dir()}/accounts/hub/environments/${get_env("TF_VAR_ENVIRONMENT", "dev")}/observability.tfvars",
      "${get_parent_terragrunt_dir()}/accounts/hub/environments/${get_env("TF_VAR_ENVIRONMENT", "dev")}/platform.tfvars",
    ]
  }
}

remote_state {
  backend = "s3"
  generate = {
    path      = "remotebackend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = local.common_vars.locals.backend_bucket_name
    key            = "${local.account_vars.locals.project_folder}/${local.stack_rel_to_acct}/terraform.tfstate"
    region         = local.common_vars.locals.backend_region
    encrypt        = local.common_vars.locals.backend_encrypt
    dynamodb_table = local.common_vars.locals.backend_dynamodb_lock
    profile        = local.common_vars.locals.backend_profile
  }
}
