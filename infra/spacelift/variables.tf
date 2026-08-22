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

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint via Tailscale, e.g. https://pve.tailnet-name.ts.net:8006 (not secret)"
  type        = string
}

variable "tailscale_version" {
  description = "Tailscale static binary version for run hooks; https://pkgs.tailscale.com/stable/"
  type        = string
  # renovate: datasource=github-releases depName=tailscale/tailscale extractVersion=^v(?<version>.+)$
  default = "1.88.1"
}

# Non-secret TF_VAR_* values shared with every stack via the homelab context
# (see infra/stacks/omni/terraform.tfvars.example for the omni stack's list).
variable "shared_tfvars" {
  description = "Map of variable name -> value, exposed to all stacks as TF_VAR_<name>"
  type        = map(string)
  default     = {}
}
