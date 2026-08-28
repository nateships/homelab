# Remote-managed tunnel: the in-cluster cloudflared connects with the
# token and gets its ingress rules from this config. The DNS record
# that sends public traffic through the tunnel lands separately at
# cutover.
resource "random_bytes" "tunnel_secret" {
  length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "k8s" {
  account_id    = var.r2_account_id
  name          = "homelab-k8s"
  tunnel_secret = random_bytes.tunnel_secret.base64
  config_src    = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "k8s" {
  account_id = var.r2_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.k8s.id
  config = {
    ingress = [
      {
        hostname = var.seerr_public_hostname
        service  = "http://seerr.seerr:5055"
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "k8s" {
  account_id = var.r2_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.k8s.id
}

# The cutover switch: publishing this name sends public traffic
# through the tunnel to the in-cluster seerr.
locals {
  seerr_zone_name = join(".", slice(split(".", var.seerr_public_hostname), 1, length(split(".", var.seerr_public_hostname))))
}

data "cloudflare_zones" "seerr" {
  name = local.seerr_zone_name
}

resource "cloudflare_dns_record" "seerr" {
  zone_id = data.cloudflare_zones.seerr.result[0].id
  name    = var.seerr_public_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.k8s.id}.cfargotunnel.com"
  ttl     = 1 # proxied records use automatic TTL
  proxied = true
}

# ESO reads the token at cloudflared/password.
resource "onepassword_item" "cloudflared" {
  vault      = data.onepassword_vault.homelab.uuid
  title      = "cloudflared"
  category   = "password"
  password   = data.cloudflare_zero_trust_tunnel_cloudflared_token.k8s.token
  note_value = "Tunnel token for the in-cluster cloudflared; minted by the cloudflare stack."
}
