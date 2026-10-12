variable "cluster_arn" {
  description = "EKS cluster ARN — the server value ArgoCD uses to register the local cluster"
  type        = string
}

variable "argocd_role_arn" {
  description = "ArgoCD capability role ARN — written to platform-config so the EKSCluster RGD reads it (externalRef) as the spoke AccessEntry principal"
  type        = string
}

variable "manifests_repo" {
  description = "ECR repo URL of the rendered-manifests OCI artifact the root Application watches (repoURL oci://...); from the ecr stack output"
  type        = string
}

variable "manifests_tag" {
  description = "OCI channel tag the root Application tracks (targetRevision) — the environment name; matches MANIFESTS_TAG in the pipeline"
  type        = string
}

variable "ack_created_roles_boundary_arn" {
  description = "Permissions boundary every role ACK creates must carry — written to platform-config so eks.k can read it via externalRef"
  type        = string
}

variable "platform_repo_name" {
  description = "CodeCommit repo name of the platform repo — builds the git source URL for the digest-pinned layer-1-rgds Application (platform/gitops/apps-pinned). Comes from platform.tfvars, same as in the pipeline and eks stacks."
  type        = string
}

variable "spoke1_carm_role_arn" {
  description = "ARN of the spoke1 account's CARM trust role (accounts/spoke/stacks/carm-trust output) — the IAMRoleSelector routes any ACK resource in namespace spoke1 to this role"
  type        = string
}
