# ACK CARM (Cross-Account Resource Management): the spoke account trusts the
# central account's ACK capability role, so ACK — running in the central hub —
# can create this account's VPC + EKS cluster directly, no VPC peering, no custom
# networking. The managed EKS ACK capability runs OUTSIDE our cluster with no
# access to its own controller namespace, so the classic OSS-ACK mechanism
# (`ack-role-account-map` ConfigMap) does not apply here. The real mechanism,
# confirmed against the EKS user guide and validated live: an `IAMRoleSelector`
# CR (services.k8s.aws/v1alpha1) applied in OUR OWN cluster, mapping a namespace
# to this role ARN — no ConfigMap, no controller-namespace access needed.
module "carm_trust_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.2"

  name = "${var.project}-ack-carm-trust"

  # Map key becomes the statement Sid — AWS only allows alphanumeric there
  # (no underscores), hence "ackcarm" not "ack_carm".
  # sts:TagSession (not just sts:AssumeRole) is REQUIRED here — ACK's IAMRoleSelector
  # mechanism attaches session tags on assume-role; without TagSession in the trust
  # policy the assume fails with AccessDenied (confirmed empirically + AWS docs).
  trust_policy_permissions = {
    ackcarm = {
      actions = ["sts:AssumeRole", "sts:TagSession"]
      principals = [{
        type        = "AWS"
        identifiers = [var.trusted_role_arn]
      }]
    }
  }

  # Scoped to exactly the ACK controllers our RGDs use (vpc.k: ec2 VPC/Subnet/
  # InternetGateway/ElasticIPAddress/RouteTable/NATGateway; eks.k: eks Cluster/
  # Nodegroup/AccessEntry/Addon + iam Role) — not AdministratorAccess. Policies
  # below are each controller's OWN officially published recommended policy
  # (aws-controllers-k8s/<svc>-controller/config/iam/recommended-*), not hand-rolled:
  # - ec2: AWS ships no narrower managed policy for ec2-controller than this.
  # - eks/iam: their recommended-inline-policy files, verbatim.
  policies = {
    ec2fullaccess = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  }

  create_inline_policy = true
  inline_policy_permissions = {
    ekscontroller = {
      actions = [
        "eks:*",
        "iam:GetRole",
        "iam:PassRole",
        "iam:ListAttachedRolePolicies",
        "ec2:DescribeSubnets",
      ]
      resources = ["*"]
    }
    iamcontroller = {
      actions = [
        "iam:GetGroup", "iam:CreateGroup", "iam:DeleteGroup", "iam:UpdateGroup",
        "iam:GetRole", "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole",
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
    # NOT in either controller's official recommended policy — a gap in AWS's own
    # reference policies. The FIRST EKS cluster and the FIRST nodegroup ever created
    # in an account each need AWS to auto-create their own distinct service-linked
    # role (one for the cluster, a SEPARATE one for the nodegroup) — missing either
    # fails with "InvalidParameterException/InvalidRequestException: ... Service-Linked
    # Role could not be created ... iam:CreateServiceLinkedRole". Scoped to only these
    # two EKS-related service-linked roles, not any service, via the condition.
    eksservicelinkedrole = {
      actions = ["iam:CreateServiceLinkedRole"]
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
  }

  tags = var.tags
}
