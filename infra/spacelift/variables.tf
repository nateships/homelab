variable "op_vault" {
  description = "1Password vault holding homelab secrets"
  type        = string
  default     = "homelab"
}

variable "repository" {
  description = "GitHub repository (name only) Spacelift stacks track"
  type        = string
  default     = "homelab"
}

variable "branch" {
  description = "Branch stacks track"
  type        = string
  default     = "main"
}


variable "runner_image" {
  description = "Runner image for all stacks: Ansible, op, and Tailscale baked in (built by .github/workflows/runner-image.yaml)"
  type        = string
  default     = "ghcr.io/nateships/spacelift-runner:latest"
}

# Non-secret values passed to stacks as TF_VAR_* through the homelab context.
# Set each one as an individual TF_VAR_* env on the admin stack.
