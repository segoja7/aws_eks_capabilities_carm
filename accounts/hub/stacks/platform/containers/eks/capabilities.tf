module "ack" {
  source  = "terraform-aws-modules/eks/aws//modules/capability"
  version = "21.24.0"

  type         = "ACK"
  cluster_name = module.eks.cluster_name

  iam_role_policies = {
    ec2fullaccess = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  }

  iam_policy_statements = {
    ekscontroller = {
      actions   = ["eks:*", "iam:GetRole", "iam:PassRole", "iam:ListAttachedRolePolicies", "ec2:DescribeSubnets"]
      resources = ["*"]
    }
    iamcontroller = {
      actions = [
        "iam:GetGroup", "iam:CreateGroup", "iam:DeleteGroup", "iam:UpdateGroup",
        "iam:GetRole", "iam:DeleteRole", "iam:UpdateRole",
        "iam:PutRolePermissionsBoundary", "iam:PutUserPermissionsBoundary",
        "iam:GetUser", "iam:CreateUser", "iam:DeleteUser", "iam:UpdateUser",
        "iam:GetPolicy", "iam:CreatePolicy", "iam:DeletePolicy",
        "iam:GetPolicyVersion", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
        "iam:ListPolicyVersions", "iam:ListPolicyTags",
        "iam:ListAttachedGroupPolicies", "iam:GetGroupPolicy", "iam:PutGroupPolicy",
        "iam:AttachGroupPolicy", "iam:DetachGroupPolicy", "iam:DeleteGroupPolicy",
        "iam:ListAttachedRolePolicies", "iam:ListRolePolicies", "iam:GetRolePolicy",
        "iam:PutRolePolicy", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
        "iam:DeleteRolePolicy", "iam:ListAttachedUserPolicies", "iam:ListUserPolicies",
        "iam:GetUserPolicy", "iam:PutUserPolicy", "iam:AttachUserPolicy",
        "iam:DetachUserPolicy", "iam:DeleteUserPolicy", "iam:ListRoleTags",
        "iam:ListUserTags", "iam:TagPolicy", "iam:UntagPolicy", "iam:TagRole",
        "iam:UntagRole", "iam:TagUser", "iam:UntagUser",
        "iam:RemoveClientIDFromOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviderTags",
        "iam:UpdateOpenIDConnectProviderThumbprint",
        "iam:UntagOpenIDConnectProvider", "iam:AddClientIDToOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider", "iam:GetOpenIDConnectProvider",
        "iam:TagOpenIDConnectProvider", "iam:CreateOpenIDConnectProvider",
        "iam:UpdateAssumeRolePolicy",
      ]
      resources = ["*"]
    }
  
    eksservicelinkedrole = {
      actions   = ["iam:CreateServiceLinkedRole"]
      resources = [
        "arn:aws:iam::*:role/aws-service-role/eks.amazonaws.com/AWSServiceRoleForAmazonEKS",
        "arn:aws:iam::*:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup",
      ]
      condition = [{
        test     = "StringEquals"
        variable = "iam:AWSServiceName"
        values   = ["eks.amazonaws.com", "eks-nodegroup.amazonaws.com"]
      }]
    }
    # Cross-account claims (IAMRoleSelector) assume the spoke's CARM role.
    assumespokecarm = {
      actions   = ["sts:AssumeRole", "sts:TagSession"]
      resources = ["arn:aws:iam::*:role/${var.spoke_carm_role_name}"]
    }

    createroleboundedonly = {
      actions   = ["iam:CreateRole"]
      resources = ["*"]
      condition = [{
        test     = "StringEquals"
        variable = "iam:PermissionsBoundary"
        values   = [aws_iam_policy.ack_created_roles_boundary.arn]
      }]
    }
  }

  tags = var.tags
}

module "kro" {
  source  = "terraform-aws-modules/eks/aws//modules/capability"
  version = "21.24.0"

  type         = "KRO"
  cluster_name = module.eks.cluster_name

  tags = var.tags
}

module "argocd" {
  source  = "terraform-aws-modules/eks/aws//modules/capability"
  version = "21.24.0"

  type         = "ARGOCD"
  cluster_name = module.eks.cluster_name


  configuration = {
    argo_cd = {
      aws_idc = {
        idc_instance_arn = one(data.aws_ssoadmin_instances.this.arns)
      }
      namespace = "argocd"
      rbac_role_mapping = [{
        role = "ADMIN"
        identity = [{
          id   = aws_identitystore_group.argocd_admin.group_id
          type = "SSO_GROUP"
        }]
      }]
    }
  }

  iam_policy_statements = {
    ECRRead = {
      actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
      ]
      resources = ["*"]
    }
    CodeCommitPull = {
      actions = ["codecommit:GitPull"]
      resources = [
        "arn:${data.aws_partition.current.partition}:codecommit:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${var.platform_repo_name}",
        var.claims_repo_arn,
      ]
    }
  }

  tags = var.tags
}

# https://docs.aws.amazon.com/eks/latest/userguide/kro-permissions.html
# Demo = ClusterAdmin; production = a custom ClusterRole scoped to the ACK apiGroups bound to a stable group.

resource "time_sleep" "capabilities_ready" {
  depends_on      = [module.argocd, module.kro, module.ack]
  create_duration = "60s"
}

resource "aws_eks_access_policy_association" "capabilities" {
  for_each = {
    argocd = module.argocd.iam_role_arn
    kro    = module.kro.iam_role_arn
  }

  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [time_sleep.capabilities_ready]
}

# The account's IAM Identity Center instance (single-region, in us-east-1).
data "aws_ssoadmin_instances" "this" {}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Add your SSO user to this group in the IdC console to log into ArgoCD.
resource "aws_identitystore_group" "argocd_admin" {
  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)
  display_name      = var.argocd_admin_idc_group
  description       = "ArgoCD ADMIN — mapped via the EKS ArgoCD capability"
}

# Optionally map an EXISTING IdC user into the admin group (not create one — the
# user already exists via IAM Identity Center / SSO, e.g. the person logged in
# via `aws configure sso`). Looked up by username, not created.
data "aws_identitystore_user" "argocd_admin" {
  count             = var.argocd_admin_user != null ? 1 : 0
  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = var.argocd_admin_user
    }
  }
}

resource "aws_identitystore_group_membership" "argocd_admin" {
  count             = var.argocd_admin_user != null ? 1 : 0
  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)
  group_id          = aws_identitystore_group.argocd_admin.group_id
  member_id         = data.aws_identitystore_user.argocd_admin[0].user_id
}
