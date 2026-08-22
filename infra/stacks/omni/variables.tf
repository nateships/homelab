variable "proxmox_node" {
  description = "Proxmox node name to place the Omni LXC on"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for the Proxmox API (self-signed certs)"
  type        = bool
  default     = true
}

variable "omni_ct_id" {
  description = "VMID for the Omni LXC"
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

variable "ct_datastore" {
  description = "Datastore for the LXC rootfs"
  type        = string
  default     = "local-lvm"
}

variable "ct_template_file_id" {
  description = "LXC template, e.g. local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for root inside the LXC"
  type        = string
}
