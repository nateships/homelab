# Unprivileged LXC that runs self-hosted Omni (Docker Compose) and the
# Proxmox infra provider container.
#
# Two things OpenTofu cannot fully express for LXCs (see docs/BOOTSTRAP.md):
#   1. /dev/net/tun passthrough, required by the Omni container (SideroLink
#      runs userspace WireGuard over a TUN device). Applied post-create on the
#      Proxmox host:
#        pct set <vmid> --dev0 path=/dev/net/tun
#   2. Docker install inside the container.
resource "proxmox_virtual_environment_container" "omni" {
  node_name    = var.proxmox_node
  vm_id        = var.omni_ct_id
  description  = "Self-hosted Sidero Omni + Proxmox infra provider (managed by OpenTofu)"
  unprivileged = true
  started      = true

  # Docker-in-LXC requirements
  features {
    nesting = true
    keyctl  = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
    swap      = 0
  }

  disk {
    datastore_id = var.ct_datastore
    size         = 32
  }

  operating_system {
    template_file_id = var.ct_template_file_id
    type             = "ubuntu"
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = "omni"

    ip_config {
      ipv4 {
        address = var.omni_ct_ip
        gateway = var.omni_ct_gateway
      }
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }
}
