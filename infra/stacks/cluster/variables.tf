# Supplied as TF_VAR_* by the homelab context (admin stack).
variable "omni_domain" {
  description = "Bare Omni domain, e.g. omni.example.com"
  type        = string
}

variable "proxmox_node" {
  description = "Proxmox node name; the workers' topology zone label"
  type        = string
}
