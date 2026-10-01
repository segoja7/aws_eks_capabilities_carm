# Registry host shared by every repo (strip the /namespace/lib path off any URL).
output "registry_url" {
  value = split("/", values(module.ecr)[0].repository_url)[0]
}

output "namespace" {
  value = var.ecr_namespace
}

output "repository_arns" {
  value = concat([for m in module.ecr : m.repository_arn], [module.manifests.repository_arn])
}

# Full URL (host/namespace/manifests) — the OCI push target and ArgoCD repoURL.
output "manifests_url" {
  value = module.manifests.repository_url
}

# name -> full repo URL (host/namespace/lib), handy for reference.
output "repository_urls" {
  value = { for k, m in module.ecr : k => m.repository_url }
}

# AWS Signer profile ARN managed signing signs with. Consumed by the cicd role
# (signer:SignPayload) and by the CI notation-verify gate's trust policy.
output "signing_profile_arn" {
  value = aws_signer_signing_profile.platform.arn
}
