# API token for the strrl cloudflare-tunnel ingress controller
# (kubernetes/apps/cloudflare-tunnel). Minted here so it is not a
# hand-made token: the controller creates its own tunnel and DNS
# records, so it needs account-level tunnel write plus zone-level DNS
# write and zone read.
locals {
  # Permission-group ids by name. A duplicate name fails the plan on
  # the duplicate map key, matching the guarantee one() gave.
  perm_id = {
    for g in data.cloudflare_account_api_token_permission_groups_list.all.result :
    g.name => g.id
    if contains(["Cloudflare Tunnel Write", "DNS Write", "Zone Read"], g.name)
  }
  # Account-owned tokens reject an all-zones wildcard; enumerate each
  # zone as its own resource instead (also tighter than a wildcard).
  zone_dns_resources = {
    for z in data.cloudflare_zones.all.result :
    "com.cloudflare.api.account.zone.${z.id}" => "*"
  }
}

data "cloudflare_zones" "all" {
  account = {
    id = local.cloudflare_account_id
  }
}

resource "cloudflare_account_token" "tunnel_ingress" {
  account_id = local.cloudflare_account_id
  name       = "cloudflare-tunnel-ingress-controller"
  policies = [
    {
      effect            = "allow"
      permission_groups = [{ id = local.perm_id["Cloudflare Tunnel Write"] }]
      resources = jsonencode({
        "com.cloudflare.api.account.${local.cloudflare_account_id}" = "*"
      })
    },
    {
      effect = "allow"
      permission_groups = [
        { id = local.perm_id["DNS Write"] },
        { id = local.perm_id["Zone Read"] },
      ]
      resources = jsonencode(local.zone_dns_resources)
    },
  ]
}

# ESO reads the token value at cloudflare-tunnel/password.
resource "onepassword_item" "cloudflare_tunnel" {
  vault      = data.onepassword_vault.homelab.uuid
  title      = "cloudflare-tunnel"
  category   = "login"
  username   = local.cloudflare_account_id
  password   = cloudflare_account_token.tunnel_ingress.value
  note_value = "API token for the strrl tunnel ingress controller; minted by the cloudflare stack. username = account id."
}
