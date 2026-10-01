
project = "base-eks"
environment = "dev"
owner = "segoja7"
region = "us-east-1"

required_tags = {
  Project = "base-eks",
  Environment = "dev",
  Owner = "segoja7",
  ManagedBy = "Tofu-Terragrunt"
}

profile = {
   "dev"= {
    region = "us-east-1"
    profile = "segoja7-hub"

  }
}