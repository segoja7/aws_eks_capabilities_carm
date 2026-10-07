data "aws_caller_identity" "current" {}

# Separation of duties by IAM role, not by person: CodeCommit forbids the PR
# author from approving their own PR, so the one who pushes (platform-dev) and
# the one who approves (platform-approver) must be different principals.
locals {
  account_id = data.aws_caller_identity.current.account_id
  repo_arn   = "arn:aws:codecommit:${data.aws_region.current.region}:${local.account_id}:${var.platform_repo_name}"

  # Only the operator's SSO admin session may assume either role.
  operator_trust = {
    operator = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "AWS"
        identifiers = ["arn:aws:iam::${local.account_id}:root"]
      }]
      condition = [{
        test     = "ArnLike"
        variable = "aws:PrincipalArn"
        values   = ["arn:aws:iam::${local.account_id}:role/aws-reserved/sso.amazonaws.com/*AdministratorAccess*"]
      }]
    }
  }
}

# Adopt the existing roles and their inline policies instead of recreating them.
moved {
  from = aws_iam_role.platform_dev
  to   = module.platform_dev.aws_iam_role.this[0]
}

moved {
  from = aws_iam_role_policy.platform_dev
  to   = module.platform_dev.aws_iam_role_policy.inline[0]
}

moved {
  from = aws_iam_role.platform_approver
  to   = module.platform_approver.aws_iam_role.this[0]
}

moved {
  from = aws_iam_role_policy.platform_approver
  to   = module.platform_approver.aws_iam_role_policy.inline[0]
}

module "platform_dev" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.2"

  name            = "${var.project}-${var.environment}-platform-dev"
  use_name_prefix = false

  trust_policy_permissions = local.operator_trust

  create_inline_policy = true
  inline_policy_permissions = {
    pullrequests = {
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
    nodirectpush = {
      sid       = "NoDirectPushToTrunk"
      effect    = "Deny"
      actions   = ["codecommit:GitPush"]
      resources = [local.repo_arn]
      condition = [{
        test     = "StringEquals"
        variable = "codecommit:References"
        values   = ["refs/heads/${var.platform_repo_branch}"]
      }]
    }
  }

  tags = var.tags
}

module "platform_approver" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.2"

  name            = "${var.project}-${var.environment}-platform-approver"
  use_name_prefix = false

  trust_policy_permissions = local.operator_trust

  create_inline_policy = true
  inline_policy_permissions = {
    approvals = {
      sid = "PullRequestApprovals"
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

  tags = var.tags
}
