# Frontier 2's second checkpoint: ArgoCD doesn't verify OCI signatures on pull
# (argo-cd.readthedocs.io/user-guide/source-integrity-git-gpg/; tracked in
# argoproj/argo-cd#22609). The PreSync hook Job (bundled in the artifact's
# rendered/layer-1) runs `notation verify` inside the cluster before the sync.
#
# The dedicated module creates the role, its policy, and the Pod Identity
# association together. The role keeps its name, so its ARN (used by the ECR read
# allowlist in cicd/pipeline) does not change.
# Adopt the existing role and association instead of recreating them: the role name
# is taken by the old role, and recreating the association would leave the hook
# without credentials until the new one exists.
moved {
  from = module.manifests_verifier_role.aws_iam_role.this[0]
  to   = module.manifests_verifier.aws_iam_role.this[0]
}

moved {
  from = aws_eks_pod_identity_association.manifests_verifier
  to   = module.manifests_verifier.aws_eks_pod_identity_association.this["manifests-verifier"]
}

module "manifests_verifier" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.12.1"

  name = "${var.project}-manifests-verifier"

  attach_custom_policy = true

  # Only the PreSync hook's ServiceAccount may assume the role. EKS sets these
  # session tags from the association, so the trust rejects any other association.
  trust_policy_conditions = [
    {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-namespace"
      values   = ["argocd"]
    },
    {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-service-account"
      values   = ["manifests-verifier"]
    },
  ]

  policy_statements = [
    {
      # Same pull actions ArgoCD's capability role uses; GetAuthorizationToken is
      # account-level, so it can't be scoped to a repository.
      sid       = "ECRRead"
      actions   = ["ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
      resources = ["*"]
    },
    {
      # Identity-based, not resource-policy-gated: aws_signer_signing_profile_permission
      # has no GetRevocationStatus action, so the grant lives here.
      sid       = "SignerRevocation"
      actions   = ["signer:GetRevocationStatus"]
      resources = ["*"]
    },
  ]

  associations = {
    manifests-verifier = {
      cluster_name    = module.eks.cluster_name
      namespace       = "argocd"
      service_account = "manifests-verifier"
    }
  }

  tags = var.tags
}
