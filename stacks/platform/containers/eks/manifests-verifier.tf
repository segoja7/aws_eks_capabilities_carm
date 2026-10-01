# Frontier 2's second checkpoint: ArgoCD doesn't verify OCI signatures on pull
# (confirmed — argo-cd.readthedocs.io/user-guide/source-integrity-git-gpg/, and
# tracked as an open feature request: argoproj/argo-cd#22609). We close that gap
# with an ArgoCD PreSync hook Job (bundled in the OCI artifact's rendered/layer-1,
# next to the RGDs it gates) that runs `notation verify` against the manifests
# artifact INSIDE the cluster, right before the sync it protects. If verification
# fails, the hook Job fails, and ArgoCD's own documented behavior aborts the whole
# sync — nothing gets applied (argo-cd.readthedocs.io/user-guide/resource_hooks/).
#
# A DEDICATED Pod Identity role (not the ArgoCD capability role) because EKS Pod
# Identity requires the target role's trust policy to trust `pods.eks.amazonaws.com`
# specifically — the capability role's trust policy only trusts the capabilities
# service principal, not Pod Identity.
module "manifests_verifier_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.2"

  name = "${var.project}-manifests-verifier"

  # EKS Pod Identity's own documented trust policy requirement: both AssumeRole AND
  # TagSession (same two-sided-authorization pattern as CARM's IAMRoleSelector —
  # Pod Identity attaches session tags too). Scoped via condition to exactly the
  # ServiceAccount/namespace this hook runs as, so no other pod can use this role.
  trust_policy_permissions = {
    podidentity = {
      actions = ["sts:AssumeRole", "sts:TagSession"]
      principals = [{
        type        = "Service"
        identifiers = ["pods.eks.amazonaws.com"]
      }]
      condition = [
        {
          test     = "StringEquals"
          variable = "aws:RequestTag/kubernetes-namespace"
          values   = ["argocd"]
        },
        {
          test     = "StringEquals"
          variable = "aws:RequestTag/kubernetes-service-account"
          values   = ["manifests-verifier"]
        }
      ]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    ecrread = {
      # Same 4 actions ArgoCD's own capability role and the CI pipeline role use to
      # pull OCI content — notation verify needs to fetch the manifest + its
      # attached notary signature referrer.
      actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
      ]
      resources = ["*"] # GetAuthorizationToken is registry-level, can't be scoped; the rest are read-only pulls
    }
    # Identity-based, NOT resource-policy-gated (confirmed: aws_signer_signing_profile_permission's
    # own schema has no GetRevocationStatus action) — no cross-resource grant needed.
    signerverify = {
      actions   = ["signer:GetRevocationStatus"]
      resources = ["*"]
    }
  }

  tags = var.tags
}

resource "aws_eks_pod_identity_association" "manifests_verifier" {
  cluster_name    = module.eks.cluster_name
  namespace       = "argocd"
  service_account = "manifests-verifier"
  role_arn        = module.manifests_verifier_role.arn

  tags = var.tags
}
