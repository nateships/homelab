# DNS-01 token for the Omni LXC's certbot (the omni-config stack reads
# it at op://homelab/cloudflare-certbot/password). Minted here and
# scoped to the omni zone only, so the root token stays the single
# hand-made Cloudflare credential.
resource "cloudflare_account_token" "certbot_dns" {
  account_id = local.cloudflare_account_id
  name       = "omni-certbot-dns"
  policies = [
    {
      effect = "allow"
      permission_groups = [
        { id = local.perm_id["DNS Write"] },
        { id = local.perm_id["Zone Read"] },
      ]
      resources = jsonencode({
        "com.cloudflare.api.account.zone.${local.zone_id}" = "*"
      })
    },
  ]
}

resource "onepassword_item" "cloudflare_certbot" {
  vault      = data.onepassword_vault.homelab.uuid
  title      = "cloudflare-certbot"
  tags       = ["terraform"]
  category   = "password"
  password   = cloudflare_account_token.certbot_dns.value
  note_value = "DNS-01 token for the Omni LXC certbot; minted by the cloudflare stack."
}
