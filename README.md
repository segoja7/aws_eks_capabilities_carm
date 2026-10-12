# Terraform Terragrunt Scaffold

Enterprise-grade AWS infrastructure scaffold using Terraform and Terragrunt with a layered architecture based on Domain-Driven Design (DDD) principles. Backs the **GitOps Beyond Git** blog series: a hub-spoke EKS Capabilities platform (ArgoCD, KRO, ACK, managed) delivered via OCI and GitOps, with AWS Signer–verified supply-chain security on top.

- [Part 1 — Immutable Platform Delivery with OCI and Argo CD](https://dev.to/aws-builders/gitops-beyond-git-immutable-platform-delivery-with-oci-and-argo-cd-using-eks-capabilities-4l6c)
- Part 2 — AWS Signer in the supply chain (signing, digest pinning, and why signing alone isn't enough) — this repo's `docs/blog-part2-final.md`

## Architecture

The project implements four infrastructure layers with strict dependency ordering:

```
Foundation → Platform → Application → Observability
```

It spans **two AWS accounts in the same Organization** — a hub that owns the EKS cluster, the CI/CD pipeline, and the ArgoCD capability, and a spoke that only trusts the hub's ACK controller to create resources on its behalf (CARM — Cross-Account Resource Management):

```
accounts/
├── hub/                                    # 700922282251 — profile: segoja7-hub
│   ├── account.hcl
│   ├── environments/dev/
│   │   ├── foundations.tfvars
│   │   └── platform.tfvars
│   └── stacks/
│       ├── foundation/network/vpc/         # VPC, subnets, NAT gateways
│       └── platform/
│           ├── containers/
│           │   ├── ecr/                    # kcl-modules/blueprints + manifests, repo-level Deny policies
│           │   └── eks/                    # EKS cluster + ArgoCD/KRO/ACK capabilities, IAM permissions boundary
│           ├── cicd/
│           │   ├── claims-repo/            # platform-claims CodeCommit repo + claims-dev/claims-approver roles
│           │   └── pipeline/                # platform-engineering-from-scratch repo, CodeBuild, CodePipeline,
│           │                                 # platform-dev/platform-approver roles, ECR least-privilege policies
│           └── gitops/
│               └── bootstrap/              # ArgoCD app-of-apps, AppProjects, manifests-verifier RBAC
└── spoke/                                  # 570903461087 — profile: segoja7-spoke1
    └── stacks/
        └── carm-trust/                     # IAM role the hub's ACK controller assumes into this account
```

`modules/cicd/` is the reusable Terraform module (CodeCommit, CodeBuild, CodePipeline, IAM, KMS, EventBridge) that both `claims-repo` and `pipeline` build on.

## Prerequisites

- Terraform/OpenTofu >= 1.0
- Terragrunt >= 0.50
- AWS CLI, with SSO configured for both accounts:
  - `segoja7-hub` (`aws sso login --profile segoja7-hub`)
  - `segoja7-spoke1` (`aws sso login --profile segoja7-spoke1`)
- `kubectl`, `drawio` CLI (for the diagrams in `docs/`) — optional
- The platform's KCL code (RGDs, hooks, blueprints) lives in a **separate repo**: `platform-engineering-from-scratch` — needed to actually exercise the pipeline end to end.

## Quick Start — deploying the whole platform

Dependencies between stacks force an order; `terragrunt run --all apply` has been unreliable across account boundaries in practice, so apply sequentially:

```bash
aws sso login --profile segoja7-hub
aws sso login --profile segoja7-spoke1

cd accounts/hub/stacks/foundation/network/vpc        && terragrunt apply
cd ../../../platform/containers/ecr                  && terragrunt apply
cd ../../cicd/claims-repo                            && terragrunt apply
cd ../../containers/eks                              && terragrunt apply
cd ../../cicd/pipeline                                && terragrunt apply
cd ../../../../../spoke/stacks/carm-trust             && terragrunt apply
cd ../../../hub/stacks/platform/gitops/bootstrap      && terragrunt apply
```

That's: `vpc → ecr → claims-repo → eks → pipeline → carm-trust (spoke) → bootstrap`. `eks` depends on `vpc`, `ecr` and `claims-repo`; `pipeline` depends on `eks`; `bootstrap` depends on `eks`, `ecr` and the spoke's `carm-trust` — it has to go last.

After `bootstrap`, seed the platform repo (first push has to come from an authenticated admin session, there's no PR gate on the very first commit):

```bash
git clone https://git-codecommit.us-east-1.amazonaws.com/v1/repos/platform-engineering-from-scratch
# copy in the platform-engineering-from-scratch source, then:
git push origin main
```

That push triggers the pipeline via EventBridge, which signs, renders, and opens the first promotion PR.

## Multi-Stack Operations

```bash
# Plan all stacks in one account (respects dependency order)
terragrunt run --all plan --working-dir accounts/hub

# Apply a specific layer
terragrunt run --all --working-dir accounts/hub/stacks/platform -- apply

# Destroy (reverse dependency order) — do the spoke's carm-trust and the hub's
# bootstrap/pipeline first, vpc last, or dependent stacks will block it
terragrunt run --all destroy --working-dir accounts/hub
```

## Project Structure

```
.
├── root.hcl                    # Root Terragrunt config (remote state, providers)
├── common/
│   ├── common.hcl              # Transversal config shared by both accounts
│   ├── common.tfvars           # Common variable values
│   ├── variables.tf            # Shared variable definitions
│   └── additional_providers/   # provider_aws.hcl, provider_kubectl.hcl
├── accounts/
│   ├── hub/                    # see Architecture above
│   └── spoke/                  # see Architecture above
├── modules/
│   └── cicd/                   # reusable CodeCommit/CodeBuild/CodePipeline module
├── docs/                       # architecture diagrams (.drawio/.png) + blog drafts
└── .kiro/
    ├── steering/               # AI agent steering rules
    ├── skills/                 # AI agent skills
    │   └── iac-versioning-commits/  # Commit and versioning standards
    ├── agents/                 # Agent configurations
    └── settings/               # MCP settings
```

## Environments

Configuration follows a hierarchical precedence (highest to lowest):

1. `accounts/{account}/environments/{env}/*.tfvars` — environment-specific overrides
2. `common/common.tfvars` — shared values
3. Stack-level `variables.tf` defaults

Each account's `account.hcl` holds the one thing that actually diverges per account — `profile`, `account_id`, `project`, tags. Everything else (backend, provider shape, tfvars loading) is transversal, defined once in `root.hcl`/`common/`.

```
accounts/hub/environments/dev/
├── foundations.tfvars
└── platform.tfvars
```

## Stack Convention

Every stack contains:

| File | Purpose |
|------|---------|
| `terragrunt.hcl` | Dependencies, includes, inputs |
| `main.tf` | Resource/module definitions |
| `variables.tf` | Input variables |
| `outputs.tf` | Output values |

## Replicating the blog series

1. Deploy this repo (Quick Start above) — gives you the hub/spoke accounts, EKS cluster, ECR repos with least-privilege policies, the CI/CD pipeline, and ArgoCD bootstrapped.
2. Push the `platform-engineering-from-scratch` repo's content to the `platform-engineering-from-scratch` CodeCommit repo this stack created — that repo holds the KCL blueprints/RGDs and the PreSync verification hook (see `docs/blog-part2-final.md`, "Prerequisites").
3. Diagrams referenced in both posts live in `docs/`: `blog-supply-chain-architecture.{drawio,png}` (full flow, sign → pin → promote → verify) and `blog-signing-gate-flow.{drawio,png}` (what happens inside CodeBuild).
4. A worked, reproducible example of the PreSync hook rejecting an unverifiable digest is in `docs/blog-part2-final.md` under "Reproduciendo el rechazo" — copy that Job manifest as-is, swap in your own registry/signing-profile ARN.

## Versioning

This project uses **IaC Tagging Code** (MAJOR.MINOR.PATCH):

- **MAJOR** — Environment additions/removals, framework changes
- **MINOR** — New stacks, modules, or resources (backward compatible)
- **PATCH** — Bug fixes, config tuning, documentation

Commits follow [Conventional Commits](https://www.conventionalcommits.org/) extended with contextual action lines. See `.kiro/skills/iac-versioning-commits/` for the full specification.

## Validation

```bash
# Lint
tflint --recursive

# Pre-commit hooks
pre-commit run --all-files

# Validate syntax
terragrunt validate
```

## License

No `LICENSE` file is checked into this repo yet.
