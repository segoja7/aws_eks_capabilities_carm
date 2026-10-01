# Spoke account (570903461087) — workload account inside the same AWS Organization
# as the central/HUB account. Own root, own state, own credentials: multi-account
# IaC keeps one Terragrunt root per account rather than branching a shared one.
locals {
  profile           = "segoja7-spoke1"
  project           = "base-eks-spoke1"
  deployment_region = "us-east-1"
  provider          = "aws"
  client            = "dev-to"

  environment = get_env("TF_VAR_ENVIRONMENT", "dev")

  tags = {
    ProjectCode = "base-eks-spoke1"
    Framework   = "DevSecOps-IaC"
    Account     = "spoke"
  }

  # Backend Configuration — DELIBERATELY the HUB's bucket/table/profile, not the
  # spoke's. State storage is centralized in the central account for governance
  # (one place to back up/audit every stack's state); this is independent of
  # `profile` above, which is what the generated `provider "aws"` block uses to
  # actually CREATE resources (spoke account). Terragrunt/OpenTofu keeps these two
  # concerns separate: `remote_state.config.profile` authenticates to S3/DynamoDB
  # only, never touches the resources a stack manages.
  backend_region        = "us-east-1"
  backend_bucket_name   = "base-eks-tfstate-700922282251"
  backend_profile       = "segoja7-hub"
  backend_dynamodb_lock = "db-terraform-lock-700922282251"
  backend_key           = "terraform.tfstate"
  backend_encrypt       = true
  project_folder        = "${local.provider}/${local.client}/${local.project}"
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
      profile = "segoja7-spoke1"
      region  = "us-east-1"
    }
    dev = {
      profile = "segoja7-spoke1"
      region  = "us-east-1"
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
