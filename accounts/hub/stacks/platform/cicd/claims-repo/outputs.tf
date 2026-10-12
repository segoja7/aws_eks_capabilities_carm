output "claims_repo_url" {
  value = "https://git-codecommit.${data.aws_region.current.region}.amazonaws.com/v1/repos/${aws_codecommit_repository.this.repository_name}"
}

output "claims_repo_arn" {
  value = local.repo_arn
}

output "claims_repo_name" {
  value = aws_codecommit_repository.this.repository_name
}
