# Unprivileged LXC that runs self-hosted Omni and the Proxmox infra
# provider. The omni-config playbook adds what OpenTofu cannot express:
# /dev/net/tun passthrough (SideroLink needs a TUN device) and the
# Docker install.
# The LXC template. Tofu downloads it to the node, so no manual pveam step.
# The checksum comes from the signed index that pveam verifies against:
# https://download.proxmox.com/images/aplinfo-pve-9.dat. No renovate
# datasource covers these images; bump the version and checksum together
# by hand.
resource "proxmox_download_file" "debian_template" {
  node_name          = var.proxmox_node
  datastore_id       = "local" # must have "Container templates" content enabled
  content_type       = "vztmpl"
  url                = "https://download.proxmox.com/images/system/debian-13-standard_13.6-1_amd64.tar.zst"
  checksum           = "4c0c27ca6ceab5ef0b84db57825a00f26157ef1854bafe97297813e1cbe8ecb8cc9c453cab6b3b0efe1ba193a50c47ece1e41d950e411b8730b835b71e9e754b"
  checksum_algorithm = "sha512"
}

resource "proxmox_virtual_environment_container" "omni" {
  node_name    = var.proxmox_node
  vm_id        = var.omni_ct_id
  description  = "Self-hosted Sidero Omni + Proxmox infra provider (managed by OpenTofu)"
  unprivileged = true
  started      = true

  # Docker-in-LXC needs nesting + keyctl. The API token can only set
  # nesting; the omni-config playbook sets keyctl. This resource
  # ignores feature drift.
  features {
    nesting = true
  }

  lifecycle {
    # operating_system: a template bump must not recreate the container.
    # The template only matters at creation; rebuild with -replace.
    ignore_changes = [features, device_passthrough, operating_system]
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

    # Without this the LXC inherits the host resolv.conf, which
    # tailscale points at 100.100.100.100 (dead in a fresh container).
    dns {
      servers = [var.omni_ct_gateway]
    }

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
