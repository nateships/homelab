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

# ESO reads the token at cloudflared/password.
resource "onepassword_item" "cloudflared" {
  vault      = data.onepassword_vault.homelab.uuid
  title      = "cloudflared"
  category   = "password"
  password   = data.cloudflare_zero_trust_tunnel_cloudflared_token.k8s.token
  note_value = "Tunnel token for the in-cluster cloudflared; minted by the cloudflare stack."
}
