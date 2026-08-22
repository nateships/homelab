terraform {
  required_version = ">= 1.8"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0, < 1.0.0"
    }
  }
}
