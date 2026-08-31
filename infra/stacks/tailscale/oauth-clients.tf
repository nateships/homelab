# Every tailnet credential except the stack's own: the root
# tailscale-terraform client (union scopes, hand-made) mints these, and
# their secrets land in the 1Password items the consumers already read.
# Scope or tag changes are plan/apply; rotation is tofu taint.

# depends_on: tag ownership must apply before minting.
resource "tailscale_oauth_client" "spacelift" {
  description = "spacelift-runs"
  scopes      = ["auth_keys"]
  tags        = ["tag:spacelift"]
  depends_on  = [tailscale_acl.tailnet]
}

resource "onepassword_item" "tailscale_spacelift" {
  vault      = data.onepassword_vault.homelab.uuid
  note_value = "tailscale OAuth client id: ${tailscale_oauth_client.spacelift.id}"
  title      = "tailscale-spacelift"
  tags       = ["terraform"]
  category   = "password"
  password   = tailscale_oauth_client.spacelift.key
}


resource "tailscale_oauth_client" "omni" {
  description = "omni-lxc"
  scopes      = ["auth_keys"]
  tags        = ["tag:omni"]
  depends_on  = [tailscale_acl.tailnet]
}

resource "onepassword_item" "tailscale_omni" {
  vault      = data.onepassword_vault.homelab.uuid
  note_value = "tailscale OAuth client id: ${tailscale_oauth_client.omni.id}"
  title      = "tailscale-omni"
  tags       = ["terraform"]
  category   = "password"
  password   = tailscale_oauth_client.omni.key
}


resource "tailscale_oauth_client" "tsidp" {
  description = "tsidp"
  scopes      = ["auth_keys"]
  tags        = ["tag:tsidp"]
  depends_on  = [tailscale_acl.tailnet]
}

resource "onepassword_item" "tailscale_tsidp" {
  vault      = data.onepassword_vault.homelab.uuid
  note_value = "tailscale OAuth client id: ${tailscale_oauth_client.tsidp.id}"
  title      = "tailscale-tsidp"
  tags       = ["terraform"]
  category   = "password"
  password   = tailscale_oauth_client.tsidp.key
}


resource "tailscale_oauth_client" "k8s_operator" {
  description = "kubernetes-operator"
  scopes      = ["auth_keys", "devices:core", "services"]
  tags        = ["tag:k8s-operator"]
  depends_on  = [tailscale_acl.tailnet]
}

resource "onepassword_item" "tailscale_operator" {
  vault    = data.onepassword_vault.homelab.uuid
  title    = "tailscale-operator"
  tags     = ["terraform"]
  category = "login"
  username = tailscale_oauth_client.k8s_operator.id
  password = tailscale_oauth_client.k8s_operator.key
}
