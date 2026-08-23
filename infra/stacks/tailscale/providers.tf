# 1Password authenticates via OP_SERVICE_ACCOUNT_TOKEN, supplied by the
# "bootstrap" context (this stack opts in with labels: [op]).
provider "onepassword" {}

# Tailscale API credentials come from the "tailscale-terraform" 1Password
# item: username = OAuth client ID, password = OAuth client secret.
# This is a separate OAuth client from the runner's auth-key one; it needs
# the policy-file write scope, plus the auth-keys write scope with
# tag:talos allowed (mints the node join key).
provider "tailscale" {
  oauth_client_id     = data.onepassword_item.oauth.username
  oauth_client_secret = data.onepassword_item.oauth.password
}
