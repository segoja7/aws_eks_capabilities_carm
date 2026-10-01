# Load variables in locals
locals {
  # Default values for variables
  # Central/HUB account (700922282251) — Organizations management account.
  profile           = "segoja7-hub"
  project           = "base-eks"
  deployment_region = "us-east-1"
  provider          = "aws"
  client = "dev-to"

  environment = get_env("TF_VAR_ENVIRONMENT", "dev")
  # Set tags according to company policies
  tags = {
    ProjectCode = "base-eks"
    Framework   = "DevSecOps-IaC"
  }

  # Backend Configuration
  backend_region        = "us-east-1"
  backend_bucket_name   = "base-eks-tfstate-700922282251"
  backend_profile       = "segoja7-hub"
  backend_dynamodb_lock = "db-terraform-lock-700922282251"
  backend_key           = "terraform.tfstate"
  backend_encrypt = true
  # format cloud provider/client/projectname
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
      profile = "segoja7-hub"
      region = "us-east-1"
}
    dev  = {
      profile = "segoja7-hub"
      region = "us-east-1"
}
    prod = {
      profile = "segoja7-hub"
      region = "us-east-1"

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
