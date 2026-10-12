#  - Publish: only the pipeline role.
#  - Read:    only the pipeline, ArgoCD's capability role and the PreSync verifier.
locals {
  pipeline_role_arn = module.cicd.iam_role_arn
  read_allowlist    = concat([local.pipeline_role_arn], var.ecr_read_principal_arns)
}

moved {
  from = aws_ecr_repository_policy.pipeline_only_publish
  to   = aws_ecr_repository_policy.least_privilege
}

resource "aws_ecr_repository_policy" "least_privilege" {
  for_each = toset(var.ecr_repository_arns)

  repository = element(split("repository/", each.value), 1)
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyPublishOutsidePipeline"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload"]
        Condition = {
          ArnNotEquals = { "aws:PrincipalArn" = local.pipeline_role_arn }
        }
      },
      {
        Sid       = "DenyReadOutsideAllowlist"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
        Condition = {
          ArnNotEquals = { "aws:PrincipalArn" = local.read_allowlist }
        }
      },
    ]
  })
}
