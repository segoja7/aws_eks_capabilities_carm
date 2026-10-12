
module "manifests_verifier" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.12.1"

  name = "${var.project}-manifests-verifier"

  attach_custom_policy = true

  # Only the PreSync hook's ServiceAccount may assume the role.
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
      sid       = "ECRRead"
      actions   = ["ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
      resources = ["*"]
    },
    {
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
