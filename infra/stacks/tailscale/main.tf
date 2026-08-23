data "onepassword_vault" "homelab" {
  name = "homelab"
}

data "onepassword_item" "oauth" {
  vault = data.onepassword_vault.homelab.uuid
  title = "tailscale-terraform"
}

# The WHOLE tailnet policy file. An apply replaces everything in the admin
# console; console edits become drift that the next apply reverts.
resource "tailscale_acl" "tailnet" {
  acl = file("${path.module}/policy.hujson")

  # Take ownership on first apply; the repo policy replaces console state.
  overwrite_existing_content = true
}
