# Execution-context config, transversal to every account. Isolated from
# common.hcl so the "where/how am I running" concern (workspace + local-vs-CI)
# stays separate from the "what shared values exist" concern.
#
#   workspace : the environment/workspace name (dev|qa|stg|prod), driven by the
#               TF_VAR_ENVIRONMENT env var — same contract the stacks already use.
#   pipeline  : "true" when running inside CI (assumed role, no AWS CLI profile),
#               "false" for local runs (SSO/named profile). Toggled via the
#               TF_VAR_PIPELINE env var so no code change is needed to switch.
#               Drives whether root.hcl's remote_state uses backend_profile or
#               lets the assumed-role/default credential chain authenticate to S3.
locals {
  workspace = get_env("TF_VAR_ENVIRONMENT", "dev")
  pipeline  = get_env("TF_VAR_PIPELINE", "false")
}
