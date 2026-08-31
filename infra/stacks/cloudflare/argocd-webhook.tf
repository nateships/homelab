# Shared secret for the GitHub push webhook. ESO merges it into
# argocd-secret (webhook.github.secret); the GitHub repo webhook must
# carry the same value. Independent of the tunnel mechanism: argocd
# validates this regardless of how the request is routed.
resource "random_password" "argocd_webhook" {
  length  = 32
  special = false
}

resource "onepassword_item" "argocd_webhook" {
  vault      = data.onepassword_vault.homelab.uuid
  title      = "argocd-webhook"
  tags       = ["terraform"]
  category   = "password"
  password   = random_password.argocd_webhook.result
  note_value = "Shared secret for the GitHub -> ArgoCD push webhook; minted by the cloudflare stack. The GitHub repo webhook uses the same value."
}
