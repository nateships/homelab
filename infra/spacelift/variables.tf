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
  description = "Runner image for all stacks: Ansible, op, and Tailscale baked in (built by .github/workflows/runner-image.yaml)"
  type        = string
  default     = "ghcr.io/nateships/spacelift-runner:latest"
}

# Non-secret values passed to stacks as TF_VAR_* through the homelab context.
# Set each one as an individual TF_VAR_* env on the admin stack.
variable "proxmox_node" {
  description = "Proxmox node name that hosts the Omni LXC"
  type        = string
}

variable "omni_ct_id" {
  description = "VMID for the Omni LXC; also read by the omni-config playbook"
  type        = number
  default     = 200
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

variable "omni_domain" {
  description = "Bare Omni domain, e.g. omni.example.com; also the workload-proxy suffix"
  type        = string
}

variable "k8s_vlan_cidr" {
  description = "k8s VLAN CIDR the PVE host advertises to the tailnet, e.g. 10.0.101.0/24"
  type        = string
}

variable "r2_account_id" {
  description = "Cloudflare account id that holds the R2 etcd-backup bucket"
  type        = string
}

variable "seerr_public_hostname" {
  description = "Public hostname the tunnel routes to seerr, e.g. seerr.example.com"
  type        = string
}

variable "argocd_webhook_public_hostname" {
  description = "Public hostname the tunnel routes to the ArgoCD webhook path, e.g. argocd-webhook.example.com"
  type        = string
}

variable "argocd_appset_webhook_public_hostname" {
  description = "Public hostname the tunnel routes to the ApplicationSet webhook path, e.g. argocd-appset-webhook.example.com"
  type        = string
}

variable "r2_bucket" {
  description = "R2 bucket for Omni etcd backups"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for root inside the Omni LXC"
  type        = string
}
