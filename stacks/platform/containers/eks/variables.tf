variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the cluster in (from the vpc stack)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the control plane ENIs and nodes"
  type        = list(string)
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
}

variable "node_instance_types" {
  description = "Instance types for the managed node group"
  type        = list(string)
}

variable "node_min_size" {
  description = "Minimum nodes in the managed node group"
  type        = number
}

variable "node_max_size" {
  description = "Maximum nodes in the managed node group"
  type        = number
}

variable "node_desired_size" {
  description = "Desired nodes in the managed node group"
  type        = number
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}

variable "argocd_admin_idc_group" {
  description = "IAM Identity Center group (created here) mapped to ArgoCD's ADMIN role"
  type        = string
}

variable "platform_repo_name" {
  description = "CodeCommit platform repo ArgoCD pulls rendered manifests from; grants codecommit:GitPull to the ArgoCD capability role. Shared with the cicd stack."
  type        = string
}

variable "argocd_admin_user" {
  description = "Username of an EXISTING IdC user to map into the ArgoCD admin group (looked up, not created — they already exist via SSO). null = manage group membership by hand."
  type        = string
  default     = null
}

variable "ecr_repository_arns" {
  description = "ECR repo ARNs (blueprints + manifests) the manifests-verifier Pod Identity role reads — the PreSync hook's notation verify needs to pull the artifact + its signature."
  type        = list(string)
}
