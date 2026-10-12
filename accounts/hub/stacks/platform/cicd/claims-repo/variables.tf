variable "environment" {
  type = string
}

variable "claims_repo_name" {
  description = "CodeCommit repo name for consumer claims"
  type        = string
}

variable "claims_repo_branch" {
  description = "Branch ArgoCD's user-claims Application watches"
  type        = string
}

variable "tags" {
  type = map(string)
}
