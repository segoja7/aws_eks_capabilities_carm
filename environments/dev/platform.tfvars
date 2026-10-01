# Platform Layer - Dev Environment

# --- EKS management cluster (runs ArgoCD + KRO + ACK) ---
cluster_version     = "1.36"
node_instance_types = ["m7i-flex.large"]
node_min_size       = 1
node_max_size       = 3
node_desired_size   = 2

# --- Platform repo (SHARED on purpose by the eks and cicd stacks) ---

platform_repo_name   = "platform-engineering-from-scratch"
platform_repo_branch = "main"

# OCI

# --- ECR (KCL libraries published as OCI artifacts) ---
# One repo per library under the namespace: kcl-modules/blueprints.
ecr_namespace = "kcl-modules"
kcl_libraries = ["blueprints"]

# --- CI toolchain ---
# Pin the KCL CLI the pipeline installs. 
kcl_version = "v0.12.7"
# ORAS CLI — pushes the rendered manifests as an OCI artifact.
oras_version = "v1.2.0"

# --- ArgoCD identity ---
argocd_admin_idc_group = "platform-admins"

# Existing IdC user to map into the admin group (looked up, not created).
#   export TF_VAR_argocd_admin_user=javier.sepulveda

