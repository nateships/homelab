# API token for the strrl cloudflare-tunnel ingress controller
# (kubernetes/apps/cloudflare-tunnel). Minted here so it is not a
# hand-made token: the controller creates its own tunnel and DNS
# records, so it needs account-level tunnel write plus zone-level DNS
# write and zone read across every zone.
locals {
  tunnel_write_id = one([
    for g in data.cloudflare_account_api_token_permission_groups_list.all.result :
    g.id if g.name == "Cloudflare Tunnel Write"
  ])
  dns_write_id = one([
    for g in data.cloudflare_account_api_token_permission_groups_list.all.result :
    g.id if g.name == "DNS Write"
  ])
  zone_read_id = one([
    for g in data.cloudflare_account_api_token_permission_groups_list.all.result :
    g.id if g.name == "Zone Read"
  ])
}

resource "cloudflare_account_token" "tunnel_ingress" {
  account_id = var.r2_account_id
  name       = "cloudflare-tunnel-ingress-controller"
  policies = [
    {
      effect            = "allow"
      permission_groups = [{ id = local.tunnel_write_id }]
      resources = jsonencode({
        "com.cloudflare.api.account.${var.r2_account_id}" = "*"
      })
    },
    {
      effect = "allow"
      permission_groups = [
        { id = local.dns_write_id },
        { id = local.zone_read_id },
      ]
      resources = jsonencode({
        "com.cloudflare.api.account.zone.*" = "*"
      })
    },
  ]
}

# ESO reads the token value at cloudflare-tunnel/password.
resource "onepassword_item" "cloudflare_tunnel" {
  vault      = data.onepassword_vault.homelab.uuid
  title      = "cloudflare-tunnel"
  category   = "password"
  password   = cloudflare_account_token.tunnel_ingress.value
  note_value = "API token for the strrl tunnel ingress controller; minted by the cloudflare stack."
}
