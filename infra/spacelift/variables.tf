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

variable "runner_image" {
  description = "Runner image with op and Tailscale baked in (built by .github/workflows/runner-image.yaml)"
  type        = string
  default     = "ghcr.io/nateships/spacelift-runner:latest"
}

# Non-secret values passed to stacks as TF_VAR_* through the homelab context.
# Set each one as an individual TF_VAR_* env on the admin stack.
variable "proxmox_node" {
  description = "Proxmox node name that hosts the Omni LXC"
  type        = string
}

variable "omni_ct_ip" {
  description = "Static IP/CIDR for the Omni LXC, e.g. 192.168.10.15/24"
  type        = string
}

variable "omni_ct_gateway" {
  description = "Gateway for the Omni LXC"
  type        = string
}

variable "omni_ct_vlan" {
  description = "VLAN tag for the Omni LXC (null = untagged)"
  type        = number
  default     = null
}

variable "ssh_public_key" {
  description = "SSH public key for root inside the Omni LXC"
  type        = string
}
