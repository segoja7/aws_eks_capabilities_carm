output "carm_trust_role_arn" {
  description = "ARN of the role ACK (central account) assumes to provision resources in this spoke account. Register it in the hub's `ack-role-account-map` ConfigMap (namespace = wherever ACK's service controller runs) mapped to this spoke's account ID (570903461087)."
  value       = module.carm_trust_role.arn
}
