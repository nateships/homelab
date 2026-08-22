# Unprivileged LXC that runs self-hosted Omni (Docker Compose) and the
# Proxmox infra provider Docker container.
#
# Two things OpenTofu cannot fully express for LXCs (see docs/BOOTSTRAP.md):
#   1. /dev/net/tun passthrough, required by the Omni Docker container (SideroLink
#      runs userspace WireGuard over a TUN device). Applied post-create on the
#      Proxmox host:
#        pct set <vmid> --dev0 path=/dev/net/tun
#   2. Docker install inside the LXC.
# The LXC template. Tofu downloads it to the node, so no manual pveam step.
resource "proxmox_download_file" "debian_template" {
  node_name    = var.proxmox_node
  datastore_id = "local" # must have "Container templates" content enabled
  content_type = "vztmpl"
  url          = "http://download.proxmox.com/images/system/debian-13-standard_13.6-1_amd64.tar.zst"
}

resource "proxmox_virtual_environment_container" "omni" {
  node_name    = var.proxmox_node
  vm_id        = var.omni_ct_id
  description  = "Self-hosted Sidero Omni + Proxmox infra provider (managed by OpenTofu)"
  unprivileged = true
  started      = true

  # Docker-in-LXC needs nesting + keyctl. The API can only set nesting
  # (other feature flags require a real root@pam login; tokens do not
  # qualify), so the omni-config playbook sets keyctl and this resource
  # ignores feature drift.
  features {
    nesting = true
  }

  lifecycle {
    ignore_changes = [features, device_passthrough]
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
    template_file_id = proxmox_download_file.debian_template.id
    type             = "debian"
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = var.omni_ct_vlan
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
