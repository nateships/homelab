# Supplied as TF_VAR_* by the homelab context (admin stack).
variable "omni_domain" {
  description = "Bare Omni domain, e.g. omni.example.com"
  type        = string
}

variable "omni_ct_ip" {
  description = "Static IP/CIDR of the Omni LXC; the DNS records use the address"
  type        = string
}


variable "r2_bucket" {
  description = "R2 bucket for Omni etcd backups"
  type        = string
}
