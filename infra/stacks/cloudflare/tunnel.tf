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
        hostname = var.birdnet_public_hostname
        service  = "http://birdnet-go.birdnet-go:8080"
      },
      # GitHub push webhooks. Only the webhook path routes to each
      # controller; every other path on these hostnames hits the 404
      # rule below. Two hostnames because both controllers serve the
      # same path and cloudflared cannot rewrite paths.
      {
        hostname = var.argocd_webhook_public_hostname
        path     = "/api/webhook"
        service  = "http://argocd-server.argocd:80"
      },
      {
        hostname = var.argocd_appset_webhook_public_hostname
        path     = "/api/webhook"
        service  = "http://argocd-applicationset-controller.argocd:7000"
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
  # Last two labels: works for a subdomain and for the zone apex.
  seerr_zone_name   = join(".", slice(split(".", var.seerr_public_hostname), length(split(".", var.seerr_public_hostname)) - 2, length(split(".", var.seerr_public_hostname))))
  birdnet_zone_name = join(".", slice(split(".", var.birdnet_public_hostname), length(split(".", var.birdnet_public_hostname)) - 2, length(split(".", var.birdnet_public_hostname))))
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

data "cloudflare_zones" "birdnet" {
  name = local.birdnet_zone_name
}

# GitHub reaches the webhook paths through these names.
locals {
  argocd_webhook_zone_name        = join(".", slice(split(".", var.argocd_webhook_public_hostname), length(split(".", var.argocd_webhook_public_hostname)) - 2, length(split(".", var.argocd_webhook_public_hostname))))
  argocd_appset_webhook_zone_name = join(".", slice(split(".", var.argocd_appset_webhook_public_hostname), length(split(".", var.argocd_appset_webhook_public_hostname)) - 2, length(split(".", var.argocd_appset_webhook_public_hostname))))
}

data "cloudflare_zones" "argocd_webhook" {
  name = local.argocd_webhook_zone_name
}

resource "cloudflare_dns_record" "argocd_webhook" {
  zone_id = data.cloudflare_zones.argocd_webhook.result[0].id
  name    = var.argocd_webhook_public_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.k8s.id}.cfargotunnel.com"
  ttl     = 1 # proxied records use automatic TTL
  proxied = true
}

data "cloudflare_zones" "argocd_appset_webhook" {
  name = local.argocd_appset_webhook_zone_name
}

resource "cloudflare_dns_record" "argocd_appset_webhook" {
  zone_id = data.cloudflare_zones.argocd_appset_webhook.result[0].id
  name    = var.argocd_appset_webhook_public_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.k8s.id}.cfargotunnel.com"
  ttl     = 1 # proxied records use automatic TTL
  proxied = true
}

resource "cloudflare_dns_record" "birdnet" {
  zone_id = data.cloudflare_zones.birdnet.result[0].id
  name    = var.birdnet_public_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.k8s.id}.cfargotunnel.com"
  ttl     = 1 # proxied records use automatic TTL
  proxied = true
}
