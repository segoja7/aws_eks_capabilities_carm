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

variable "spoke1_carm_role_arn" {
  description = "ARN of the spoke1 account's CARM trust role (accounts/spoke/stacks/carm-trust output) — the IAMRoleSelector routes any ACK resource in namespace spoke1 to this role"
  type        = string
}
