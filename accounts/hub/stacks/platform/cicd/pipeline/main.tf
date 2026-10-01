data "aws_region" "current" {}

module "cicd" {
  source = "../../../../modules/cicd"

  name                   = "${var.project}-${var.environment}-cicd"
  source_repository_name = var.platform_repo_name
  source_branch          = var.platform_repo_branch
  force_destroy          = true #Demo purposes

  build_projects = {
    render = {
      buildspec = "templates/buildspec_render.yml"
      environment_variables = {
        # Read by the KCL install script (kcl-lang.io/script/install-cli.sh) to pin the CLI version
        KCL_VERSION   = var.kcl_version
        ECR_REGISTRY  = var.ecr_registry
        ECR_NAMESPACE = var.ecr_namespace
        # OCI manifest delivery (Rendered Manifests Pattern). The buildspec pushes

        MANIFESTS_REPO = var.ecr_manifests_url
        MANIFESTS_TAG  = var.environment
        ORAS_VERSION   = var.oras_version
        # Supply-chain: notation-verify gate pins to this profile (Frontier 1)
        SIGNING_PROFILE_ARN = var.signing_profile_arn
        # git-direct consumer claims
        CLAIMS_REPO_URL = "https://git-codecommit.${data.aws_region.current.region}.amazonaws.com/v1/repos/${var.platform_repo_name}"
      }
    }
  }

  stages = [
    { name = "render", build_project = "render" },
  ]

  additional_policy_statements = [
    {
      sid       = "ECRAuth"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    },
    {
      sid = "ECRModulesReadWrite"
      actions = [
        "ecr:DescribeRepositories",
        "ecr:DescribeImages",
        "ecr:ListImages",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
      ]
      resources = var.ecr_repository_arns
    },
    # ECR managed signing signs with the pusher's identity → the CodeBuild role
    # needs signer:SignPayload on the profile. GetRevocationStatus is what the
    # notation-verify gate calls at verify time (revocation check) — resource "*".
    {
      sid       = "SignerSignOnPush"
      actions   = ["signer:SignPayload"]
      resources = [var.signing_profile_arn]
    },
    {
      sid       = "SignerVerifyRevocation"
      actions   = ["signer:GetRevocationStatus"]
      resources = ["*"]
    },
  ]

  tags = var.tags
}
