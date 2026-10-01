# `project` and `profile` come from the generated provider.tf (common.hcl).

variable "environment" {
  description = "Environment name"
  type        = string
}


variable "platform_repo_name" {
  description = "CodeCommit repository name (mirror of the public GitHub platform repo). Shared with the eks stack, which grants codecommit:GitPull on it."
  type        = string
}

variable "platform_repo_branch" {
  description = "Branch CodePipeline watches (where KCL is authored)"
  type        = string
}

variable "ecr_registry" {
  description = "ECR registry host (account.dkr.ecr.region.amazonaws.com) libraries push/pull from"
  type        = string
}

variable "ecr_namespace" {
  description = "Repo prefix for the per-library repos (e.g. kcl-modules)"
  type        = string
}

variable "ecr_repository_arns" {
  description = "ARNs of every library repo — scopes the CodeBuild role's push/pull IAM"
  type        = list(string)
}

variable "kcl_version" {
  description = "KCL CLI version the pipeline installs (read by the install script's KCL_VERSION env var). Pinned to avoid the flaky latest lookup."
  type        = string
}

variable "ecr_manifests_url" {
  description = "ECR repo URL for the rendered-manifests OCI artifact — the oras push target and ArgoCD repoURL"
  type        = string
}

variable "oras_version" {
  description = "Pinned ORAS CLI version CodeBuild installs to push the manifests artifact"
  type        = string
}

variable "signing_profile_arn" {
  description = "AWS Signer profile ARN ECR managed signing uses. The CodeBuild role needs signer:SignPayload on it (so pushes get signed) and the buildspec's notation-verify gate pins its trust policy to it."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}
