# Transversal AWS provider generator. Reads the per-account account.hcl (an
# included hcl does NOT inherit the including stack's locals, so it must find
# account.hcl on its own). Emits the SAME workspace-keyed `var.profile` map the
# old per-account common.hcl emitted, so common/additional_providers/provider_kubectl.hcl
# (which also reads var.profile[terraform.workspace][...]) keeps working unchanged.
locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  acct_profile = local.account_vars.locals.profile
  acct_region  = local.account_vars.locals.region
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
variable "required_tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
variable "project" {
  type        = string
  description = "Project tool"
}
variable "profile" {
  description = "Variable for credentials management."
  default = {
    default = {
      profile = "${local.acct_profile}"
      region  = "${local.acct_region}"
    }
    dev = {
      profile = "${local.acct_profile}"
      region  = "${local.acct_region}"
    }
    prod = {
      profile = "${local.acct_profile}"
      region  = "${local.acct_region}"
    }
  }
}

provider "aws" {
  region  = var.profile[terraform.workspace]["region"]
  profile = var.profile[terraform.workspace]["profile"]

  default_tags {
    tags = var.required_tags
  }
}
EOF
}
