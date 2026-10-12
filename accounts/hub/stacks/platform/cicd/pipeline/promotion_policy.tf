data "aws_iam_policy_document" "pipeline_promotion" {
  statement {
    sid       = "CreatePromotionPR"
    actions   = ["codecommit:CreatePullRequest", "codecommit:GetPullRequest", "codecommit:GetDifferences"]
    resources = [local.repo_arn]
  }

  statement {
    sid       = "NoDirectPushToTrunkFromPipeline"
    effect    = "Deny"
    actions   = ["codecommit:GitPush"]
    resources = [local.repo_arn]
    condition {
      test     = "StringEquals"
      variable = "codecommit:References"
      values   = ["refs/heads/${var.platform_repo_branch}"]
    }
  }
}

resource "aws_iam_role_policy" "pipeline_promotion" {
  name   = "pipeline-promotion"
  role   = module.cicd.iam_role_name
  policy = data.aws_iam_policy_document.pipeline_promotion.json
}
