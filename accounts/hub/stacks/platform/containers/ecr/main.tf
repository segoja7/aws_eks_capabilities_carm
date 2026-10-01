# One ECR repository per KCL library, under a shared namespace prefix
# (e.g. kcl-modules/blueprints, kcl-modules/eksclusters). 
module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "3.2.0"

  for_each = toset(var.kcl_libraries)

  repository_name                 = "${var.ecr_namespace}/${each.value}"
  repository_image_tag_mutability = "MUTABLE"
  repository_force_delete         = true
  create_lifecycle_policy         = false

  tags = var.tags
}

# Rendered manifests as an OCI artifact (Rendered Manifests Pattern, OCI tier).

module "manifests" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "3.2.0"

  repository_name                 = "${var.ecr_namespace}/manifests"
  repository_image_tag_mutability = "MUTABLE"
  repository_force_delete         = true
  create_lifecycle_policy         = false

  tags = var.tags
}

# --- Managed signing (AWS Signer + ECR) 
# The signer profile is the IDENTITY that signs. 
resource "aws_signer_signing_profile" "platform" {
  platform_id = "Notation-OCI-SHA384-ECDSA"
  name_prefix = "platform_"
  tags        = var.tags
}

# ECR managed signing config (registry-scoped). 
resource "aws_cloudcontrolapi_resource" "signing_config" {
  type_name = "AWS::ECR::SigningConfiguration"

  desired_state = jsonencode({
    Rules = [{
      SigningProfileArn = aws_signer_signing_profile.platform.arn
      RepositoryFilters = [{
        Filter     = "${var.ecr_namespace}/*"
        FilterType = "WILDCARD_MATCH"
      }]
    }]
  })
}
