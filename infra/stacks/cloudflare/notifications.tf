# Tunnel health alerts to Grafana IRM: when the cloudflared tunnel
# degrades or drops, every public app is down, complementing the
# in-cluster deadman check. The IRM inbound webhook URL comes from the
# "grafana-irm-cloudflare" item (API Credential category, the URL in
# the credential field): create the Webhook integration in Grafana IRM
# and save its URL there before the first apply.
data "onepassword_item" "grafana_irm_cloudflare" {
  vault = data.onepassword_vault.homelab.uuid
  title = "grafana-irm-cloudflare"
}

resource "cloudflare_notification_policy_webhooks" "grafana_irm" {
  account_id = var.r2_account_id
  name       = "grafana-irm"
  url        = data.onepassword_item.grafana_irm_cloudflare.credential
}

resource "cloudflare_notification_policy" "tunnel_health" {
  account_id  = var.r2_account_id
  name        = "tunnel health"
  description = "cloudflared tunnel status changes (all tunnels)"
  enabled     = true
  alert_type  = "tunnel_health_event"
  mechanisms = {
    webhooks = [{
      id = cloudflare_notification_policy_webhooks.grafana_irm.id
    }]
  }
}
