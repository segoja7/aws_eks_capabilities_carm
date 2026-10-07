output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN (managed ArgoCD registers clusters by ARN, not API URL)"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA cert for the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL (for IRSA)"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN (for IRSA)"
  value       = module.eks.oidc_provider_arn
}

output "argocd_role_arn" {
  description = "ArgoCD capability role ARN — the principal spoke clusters grant access to (written to the platform-config ConfigMap the EKSCluster RGD reads via externalRef)"
  value       = module.argocd.iam_role_arn
}

output "manifests_verifier_role_arn" {
  description = "Pod Identity role the PreSync hook uses to pull and verify the manifests artifact — allowed to read it in the ECR repo policy"
  value       = module.manifests_verifier.iam_role_arn
}

output "ack_role_arn" {
  description = "ACK capability role ARN (central account) — the principal the spoke account's CARM trust role allows to assume, so ACK can provision VPC+EKS cross-account"
  value       = module.ack.iam_role_arn
}
