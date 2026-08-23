data "onepassword_vault" "homelab" {
  name = "homelab"
}

data "onepassword_item" "oauth" {
  vault = data.onepassword_vault.homelab.uuid
  title = "tailscale-terraform"
}

# The whole tailnet policy. An apply replaces the console policy;
# console edits drift and the next apply reverts them.
resource "tailscale_acl" "tailnet" {
  acl = templatefile("${path.module}/policy.hujson.tftpl", {
    k8s_vlan_cidr = var.k8s_vlan_cidr
  })

  # First apply takes ownership of the console policy.
  overwrite_existing_content = true
}
