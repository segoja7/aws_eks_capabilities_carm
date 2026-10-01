# `project` and `profile` come from the generated provider.tf (spoke common.hcl).

variable "trusted_role_arn" {
  description = "ARN of the central account's ACK capability role — the only principal allowed to assume this role (CARM cross-account provisioning)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}
