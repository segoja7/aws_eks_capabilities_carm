# A separate repo for consumer claims, with its own governance — not reused from
# the platform repo's platform-dev/platform-approver. No pipeline: ArgoCD's
# user-claims Application already reads straight from git, no render step needed.
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  repo_arn = "arn:${data.aws_partition.current.partition}:codecommit:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${var.claims_repo_name}"

  operator_trust = {
    operator = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "AWS"
        identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      }]
      condition = [{
        test     = "ArnLike"
        variable = "aws:PrincipalArn"
        values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/*AdministratorAccess*"]
      }]
    }
  }
}

resource "aws_codecommit_repository" "this" {
  repository_name = var.claims_repo_name
  description     = "Consumer claims — separate repo, separate governance from the platform repo."
  tags            = var.tags
}

resource "aws_codecommit_approval_rule_template" "this" {
  name        = "${var.claims_repo_name}-${var.claims_repo_branch}-approval"
  description = "PR approval rule for ${var.claims_repo_branch}"

  content = jsonencode({
    Version               = "2018-11-08"
    DestinationReferences = ["refs/heads/${var.claims_repo_branch}"]
    Statements = [{
      Type                    = "Approvers"
      NumberOfApprovalsNeeded = 1
      ApprovalPoolMembers     = ["arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/${aws_iam_role.claims_approver.name}/*"]
    }]
  })
}

resource "aws_codecommit_approval_rule_template_association" "this" {
  approval_rule_template_name = aws_codecommit_approval_rule_template.this.name
  repository_name             = aws_codecommit_repository.this.repository_name
}

resource "aws_iam_role" "claims_dev" {
  name               = "${var.project}-${var.environment}-claims-dev"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = ["sts:AssumeRole"]
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Condition = { ArnLike = { "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/*AdministratorAccess*" } }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "claims_dev" {
  name = "claims-dev"
  role = aws_iam_role.claims_dev.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PullRequestWorkflow"
        Effect   = "Allow"
        Action   = [
          "codecommit:GitPull", "codecommit:GitPush", "codecommit:CreateBranch",
          "codecommit:CreateCommit", "codecommit:CreatePullRequest", "codecommit:GetPullRequest",
          "codecommit:ListPullRequests", "codecommit:GetBranch", "codecommit:GetCommit",
          "codecommit:GetDifferences", "codecommit:MergePullRequestByFastForward",
        ]
        Resource = local.repo_arn
      },
      {
        Sid       = "NoDirectPushToTrunk"
        Effect    = "Deny"
        Action    = ["codecommit:GitPush"]
        Resource  = local.repo_arn
        Condition = { StringEquals = { "codecommit:References" = "refs/heads/${var.claims_repo_branch}" } }
      },
    ]
  })
}

resource "aws_iam_role" "claims_approver" {
  name               = "${var.project}-${var.environment}-claims-approver"
  assume_role_policy = aws_iam_role.claims_dev.assume_role_policy
  tags               = var.tags
}

resource "aws_iam_role_policy" "claims_approver" {
  name = "claims-approver"
  role = aws_iam_role.claims_approver.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "PullRequestApprovals"
      Effect   = "Allow"
      Action   = [
        "codecommit:GetPullRequest", "codecommit:ListPullRequests",
        "codecommit:GetPullRequestApprovalStates", "codecommit:UpdatePullRequestApprovalState",
        "codecommit:EvaluatePullRequestApprovalRules", "codecommit:GetCommit", "codecommit:GetDifferences",
      ]
      Resource = local.repo_arn
    }]
  })
}
