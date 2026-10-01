output "codecommit_clone_url_http" {
  description = "HTTPS clone URL of the CodeCommit source repo"
  value       = module.cicd.source_repository_clone_url_http
}

output "codecommit_repository_name" {
  value = module.cicd.source_repository_name
}

output "pipeline_name" {
  value = module.cicd.pipeline_name
}

output "artifact_bucket" {
  value = module.cicd.artifact_bucket
}

output "cicd_role_name" {
  description = "Shared CI/CD role (attach ECR push etc. here when wiring kcl mod push)"
  value       = module.cicd.iam_role_name
}
