data "onepassword_vault" "homelab" {
  name = "homelab"
}

data "onepassword_item" "oauth" {
  vault = data.onepassword_vault.homelab.uuid
  title = "tailscale-terraform"
}

# Auth key for the Talos nodes' tailscale system extension. Reusable and
# preauthorized: every node joins with the same key, and tagged devices
# never expire. The key itself lives 90 days; joining NEW nodes after
# that needs a fresh key (taint this resource and re-apply).
resource "tailscale_tailnet_key" "talos_nodes" {
  reusable      = true
  preauthorized = true
  ephemeral     = false
  expiry        = 7776000
  tags          = ["tag:talos"]
  description   = "talos nodes (siderolabs/tailscale extension)"

  depends_on = [tailscale_acl.tailnet]
}

# Hand the key to the cluster stack through 1Password: the stacks share
# no state, the vault is the existing secret channel.
resource "onepassword_item" "talos_tailscale_authkey" {
  vault    = data.onepassword_vault.homelab.uuid
  title    = "talos-tailscale-authkey"
  category = "password"
  password = tailscale_tailnet_key.talos_nodes.key
}

# The WHOLE tailnet policy file. An apply replaces everything in the admin
# console; console edits become drift that the next apply reverts.
resource "tailscale_acl" "tailnet" {
  acl = file("${path.module}/policy.hujson")

  # Take ownership on first apply; the repo policy replaces console state.
  overwrite_existing_content = true
}
