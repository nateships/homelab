# Machine classes: what the Proxmox infra provider builds when a machine
# set scales. provider_data reaches the provider as YAML. Changes only
# affect machines provisioned afterwards.
# Adopted from the retired omni-resources stack (omnictl); the import
# blocks are no-ops once the classes are in state and can be removed.
import {
  to = omni_machine_class.control_plane
  id = "proxmox-control-plane"
}

import {
  to = omni_machine_class.worker
  id = "proxmox-worker"
}

locals {
  # Shared by both classes.
  # site-specific: bridge, VLAN id, and datastore selector name this PVE
  # host's network and storage (docs/SITE.md)
  proxmox_vm = {
    sockets        = 1
    cpu_type       = "host"
    network_bridge = "vmbr0"
    # Same VLAN as the Omni LXC; SideroLink stays on one L2 segment
    vlan = 101
    # CEL expression selecting the Proxmox datastore
    storage_selector = "name == \"zpool\""
    disk_ssd         = true
    disk_discard     = true
    disk_iothread    = true
    disk_cache       = "none"
    disk_aio         = "io_uring"
  }
}

resource "omni_machine_class" "control_plane" {
  name = "proxmox-control-plane"

  auto_provision = {
    provider_id = "proxmox"

    provider_data = yamlencode(merge(local.proxmox_vm, {
      cores     = 4
      memory    = 8192
      disk_size = 60
    }))
  }
}

resource "omni_machine_class" "worker" {
  name = "proxmox-worker"

  auto_provision = {
    provider_id = "proxmox"

    # Probe the iGPU VF with xe; xe support for this generation needs
    # force_probe. Pods request the GPU as gpu.intel.com/xe.
    # site-specific: the a780 device id belongs to this host's iGPU
    # (docs/SITE.md)
    kernel_args = ["xe.force_probe=a780"]

    provider_data = yamlencode(merge(local.proxmox_vm, {
      cores     = 8
      memory    = 16384
      disk_size = 100
      # Each worker gets one iGPU virtual function from the "vGPU"
      # Proxmox resource mapping. q35 gives native PCIe. Passthrough
      # pins guest memory, so ballooning is off.
      # site-specific: the resource mapping name is created by hand in
      # the Proxmox console (docs/SITE.md)
      machine_type = "q35"
      balloon      = false
      pci_devices = [
        { mapping = "vGPU", pcie = true },
      ]
    }))
  }
}
