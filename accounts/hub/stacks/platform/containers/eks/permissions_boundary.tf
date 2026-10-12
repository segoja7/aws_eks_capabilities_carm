resource "aws_iam_policy" "ack_created_roles_boundary" {
  name        = "${var.project}-ack-created-roles-boundary"
  description = "Permissions boundary enforced on every IAM role ACK creates (see capabilities.tf createroleboundedonly)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Allow"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      },
      {
        Sid    = "DenyEscalation"
        Effect = "Deny"
        Action = [
          "iam:CreateUser", "iam:CreateRole", "iam:CreatePolicy", "iam:CreatePolicyVersion",
          "iam:AttachUserPolicy", "iam:AttachRolePolicy", "iam:AttachGroupPolicy",
          "iam:PutUserPolicy", "iam:PutRolePolicy", "iam:PutGroupPolicy",
          "iam:PutRolePermissionsBoundary", "iam:DeleteRolePermissionsBoundary",
          "iam:UpdateAssumeRolePolicy",
          "organizations:*", "account:*",
        ]
        Resource = "*"
      },
    ]
  })
  tags = var.tags
}
