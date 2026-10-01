module "ack" {
  source  = "terraform-aws-modules/eks/aws//modules/capability"
  version = "21.24.0"

  type         = "ACK"
  cluster_name = module.eks.cluster_name

  iam_role_policies = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
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
      actions   = ["codecommit:GitPull"]
      resources = ["arn:${data.aws_partition.current.partition}:codecommit:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${var.platform_repo_name}"]
    }
  }

  tags = var.tags
}

#   - ArgoCD: needs cluster-admin to deploy anything to the cluster.
#   - KRO: its auto-created AmazonEKSKROPolicy only covers RGDs + instances, NOT the
#     child resources the RGDs template (ACK resources). Documented gap:
#     https://docs.aws.amazon.com/eks/latest/userguide/kro-permissions.html
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
