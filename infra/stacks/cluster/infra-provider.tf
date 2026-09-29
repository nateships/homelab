# The Proxmox infra provider: the InfraProvider that the machine classes
# name in provider_id, plus the service account that the provider
# container logs in as. The key goes into the omni-infra-provider item.
# omni-config renders that item into omni.env, so re-run
# homelab-omni-config after the key changes. Omni keeps the old key
# valid until it expires, so the provider works until the re-run.
#
# Rotate: change renew_trigger. Omni issues a new key and the provider
# keeps its identity. A key expires after ttl.
#
# Adopted from the Omni UI; the import blocks are no-ops once the
# resources are in state and can be removed. An imported provider has
# no key in state, so the first apply renews it (renew_trigger).
import {
  to = omni_infra_provider.proxmox
  id = "proxmox"
}

import {
  to = onepassword_item.omni_infra_provider
  id = "vaults/nepmh5li3casah74lu46ip74ym/items/3cp4avfutqptyjkpt5wnnwg2ly"
}

resource "omni_infra_provider" "proxmox" {
  name          = "proxmox"
  ttl           = "8760h"
  renew_trigger = "2026-09-29"

  lifecycle {
    # Guard: the provider owns the machine requests of every VM, and
    # autodeploy applies unreviewed. Delete this line first to destroy
    # or replace on purpose.
    prevent_destroy = true
  }
}

resource "onepassword_item" "omni_infra_provider" {
  vault      = data.onepassword_vault.homelab.uuid
  title      = "omni-infra-provider"
  tags       = ["terraform"]
  category   = "password"
  note_value = "Omni infrastructure provider key (proxmox), minted by the homelab-cluster stack. NOT a service account key."
  password   = omni_infra_provider.proxmox.key
}
