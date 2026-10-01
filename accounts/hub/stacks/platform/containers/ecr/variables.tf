# `project` and `profile` come from the generated provider.tf (common.hcl).

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "ecr_namespace" {
  description = "Shared prefix for the per-library ECR repos (e.g. kcl-modules -> kcl-modules/blueprints)"
  type        = string
}

variable "kcl_libraries" {
  description = "KCL libraries published as OCI; one ECR repo is created per entry as <namespace>/<name>"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}
