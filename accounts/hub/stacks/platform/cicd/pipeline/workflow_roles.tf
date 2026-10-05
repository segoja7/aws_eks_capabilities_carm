data "aws_caller_identity" "current" {}

# Separation of duties by IAM role, not by person: CodeCommit forbids the PR
# author from approving their own PR, so the one who pushes (platform-dev) and
# the one who approves (platform-approver) must be different principals.
locals {
  account_id = data.aws_caller_identity.current.account_id
  repo_arn   = "arn:aws:codecommit:${data.aws_region.current.region}:${local.account_id}:${var.platform_repo_name}"
}

data "aws_iam_policy_document" "operator_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${local.account_id}:role/aws-reserved/sso.amazonaws.com/*AdministratorAccess*"]
    }
  }
}

resource "aws_iam_role" "platform_dev" {
  name               = "${var.project}-${var.environment}-platform-dev"
  assume_role_policy = data.aws_iam_policy_document.operator_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "platform_dev" {
  statement {
    sid = "PullRequestWorkflow"
    actions = [
      "codecommit:GitPull",
      "codecommit:GitPush",
      "codecommit:CreateBranch",
      "codecommit:CreateCommit",
      "codecommit:CreatePullRequest",
      "codecommit:GetPullRequest",
      "codecommit:ListPullRequests",
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:GetDifferences",
      "codecommit:MergePullRequestByFastForward",
    ]
    resources = [local.repo_arn]
  }

  # Direct push to the trunk is denied; the only path to main is a merged PR,
  # and CodeCommit enforces the approval rule on that merge.
  statement {
    sid       = "NoDirectPushToTrunk"
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

resource "aws_iam_role_policy" "platform_dev" {
  name   = "platform-dev"
  role   = aws_iam_role.platform_dev.id
  policy = data.aws_iam_policy_document.platform_dev.json
}

resource "aws_iam_role" "platform_approver" {
  name               = "${var.project}-${var.environment}-platform-approver"
  assume_role_policy = data.aws_iam_policy_document.operator_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "platform_approver" {
  statement {
    actions = [
      "codecommit:GetPullRequest",
      "codecommit:ListPullRequests",
      "codecommit:GetPullRequestApprovalStates",
      "codecommit:UpdatePullRequestApprovalState",
      "codecommit:EvaluatePullRequestApprovalRules",
      "codecommit:GetCommit",
      "codecommit:GetDifferences",
    ]
    resources = [local.repo_arn]
  }
}

resource "aws_iam_role_policy" "platform_approver" {
  name   = "platform-approver"
  role   = aws_iam_role.platform_approver.id
  policy = data.aws_iam_policy_document.platform_approver.json
}
