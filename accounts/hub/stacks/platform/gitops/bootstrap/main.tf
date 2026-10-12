data "aws_region" "current" {}

locals {
  platform_repo_git_url = "https://git-codecommit.${data.aws_region.current.region}.amazonaws.com/v1/repos/${var.platform_repo_name}"
}

resource "kubectl_manifest" "platform_config" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "platform-config"
      namespace = "kube-system"
    }
    data = {
      argocdRoleArn           = var.argocd_role_arn
      permissionsBoundaryArn  = var.ack_created_roles_boundary_arn
    }
  })
}


resource "kubectl_manifest" "default_appproject" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "default"
      namespace = "argocd"
    }
    spec = {
      description  = "Closed: nothing may deploy through the default project. Every Application declares its own project."
      sourceRepos  = []
      destinations = []
    }
  })
}

resource "kubectl_manifest" "bootstrap_appproject" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "bootstrap"
      namespace = "argocd"
    }
    spec = {
      description  = "App-of-apps root only: pulls the manifests artifact and creates child Applications/AppProjects in argocd."
      sourceNamespaces = ["argocd"]
      sourceRepos  = ["oci://${var.manifests_repo}", local.platform_repo_git_url]
      destinations = [{ name = "in-cluster", namespace = "argocd" }]
      namespaceResourceWhitelist = [
        { group = "argoproj.io", kind = "Application" },
        { group = "argoproj.io", kind = "AppProject" },
      ]
    }
  })
}

# ArgoCD app-of-apps.
resource "kubectl_manifest" "argocd_local_cluster" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "in-cluster"
      namespace = "argocd"
      labels    = { "argocd.argoproj.io/secret-type" = "cluster" }
    }
    stringData = {
      name    = "in-cluster"
      server  = var.cluster_arn
    }
  })
}

resource "kubectl_manifest" "argocd_root_app" {
  yaml_body = templatefile("${path.module}/root-app.yaml.tftpl", {
    manifests_repo         = var.manifests_repo
    manifests_tag          = var.manifests_tag
    platform_repo_git_url  = local.platform_repo_git_url
  })
  depends_on = [kubectl_manifest.argocd_local_cluster, kubectl_manifest.bootstrap_appproject]
}

# Cross-account (CARM): any ACK resource created in this namespace gets routed to
# the spoke1 account via the IAMRoleSelector below. 
resource "kubectl_manifest" "spoke1_namespace" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "spoke1"
    }
  })
}

# The managed EKS ACK capability runs outside our cluster with no access to its
# own controller namespace, so the classic ACK CARM mechanism (an
# `ack-role-account-map` ConfigMap in that namespace) does not apply. The real,
# validated mechanism: an IAMRoleSelector CR applied in OUR OWN cluster — ACK
# picks it up and routes any resource in a matched namespace to the given role.
resource "kubectl_manifest" "spoke1_iam_role_selector" {
  yaml_body = yamlencode({
    apiVersion = "services.k8s.aws/v1alpha1"
    kind       = "IAMRoleSelector"
    metadata = {
      name = "spoke1-account-config"
    }
    spec = {
      arn = var.spoke1_carm_role_arn
      namespaceSelector = {
        names = ["spoke1"]
      }
    }
  })
  depends_on = [kubectl_manifest.spoke1_namespace]
}

# Frontier 2's PreSync hook (rendered/layer-1/verify-manifests-hook.yaml, delivered
# via OCI) runs as this ServiceAccount — EKS Pod Identity binds it to the
# manifests-verifier IAM role (stacks/platform/containers/eks/manifests-verifier.tf).
# No annotation needed here (unlike IRSA): Pod Identity associates purely at the
# EKS/IAM level by (cluster, namespace, service account name).
resource "kubectl_manifest" "manifests_verifier_sa" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "manifests-verifier"
      namespace = "argocd"
    }
  })
}

# First native Kubernetes RBAC the verifier has — everything else it holds is AWS
# IAM. Scoped to reading exactly its own Application: the hook uses this to look
# up the digest it's about to verify (its own .spec.source.targetRevision), which
# by the time PreSync runs is already the new, git-pinned value. No other way to
# know that digest without the same self-reference problem the pinning solved.
resource "kubectl_manifest" "manifests_verifier_role" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "Role"
    metadata = {
      name      = "manifests-verifier"
      namespace = "argocd"
    }
    rules = [{
      apiGroups     = ["argoproj.io"]
      resources     = ["applications"]
      resourceNames = ["layer-1-rgds"]
      verbs         = ["get"]
    }]
  })
}

resource "kubectl_manifest" "manifests_verifier_rolebinding" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "RoleBinding"
    metadata = {
      name      = "manifests-verifier"
      namespace = "argocd"
    }
    subjects = [{
      kind      = "ServiceAccount"
      name      = "manifests-verifier"
      namespace = "argocd"
    }]
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "Role"
      name     = "manifests-verifier"
    }
  })
  depends_on = [kubectl_manifest.manifests_verifier_sa, kubectl_manifest.manifests_verifier_role]
}
