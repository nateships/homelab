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
    # Public routes migrated to the cloudflare-tunnel ingress
    # controller (per-app Ingresses). This tunnel is idle, pending
    # teardown once the controller cutover is verified.
    ingress = [
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

# Shared secret for the GitHub push webhook. ESO merges it into
# argocd-secret (webhook.github.secret); the GitHub repo webhook must
# carry the same value.
resource "random_password" "argocd_webhook" {
  length  = 32
  special = false
}

resource "onepassword_item" "argocd_webhook" {
  vault      = data.onepassword_vault.homelab.uuid
  title      = "argocd-webhook"
  category   = "password"
  password   = random_password.argocd_webhook.result
  note_value = "Shared secret for the GitHub -> ArgoCD push webhook; minted by the cloudflare stack. The GitHub repo webhook uses the same value."
}

# ESO reads the token at cloudflared/password.
resource "onepassword_item" "cloudflared" {
  vault      = data.onepassword_vault.homelab.uuid
  title      = "cloudflared"
  category   = "password"
  password   = data.cloudflare_zero_trust_tunnel_cloudflared_token.k8s.token
  note_value = "Tunnel token for the in-cluster cloudflared; minted by the cloudflare stack."
}
