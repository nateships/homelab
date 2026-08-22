variable "auth0_domain" {
  description = "Auth0 tenant domain (public: it appears in every login redirect)"
  type        = string
  default     = "CHANGE_ME.us.auth0.com"
}

variable "omni_url" {
  description = "Omni base URL, used for callback/logout/origin"
  type        = string
  default     = "https://omni.nate.cx"
}

data "onepassword_vault" "homelab" {
  name = "homelab"
}

# M2M application authorized for the Auth0 Management API (see BOOTSTRAP).
data "onepassword_item" "auth0" {
  vault = data.onepassword_vault.homelab.uuid
  title = "auth0-terraform"
}

provider "onepassword" {}

provider "auth0" {
  domain        = var.auth0_domain
  client_id     = data.onepassword_item.auth0.username
  client_secret = data.onepassword_item.auth0.password
}

resource "auth0_client" "omni" {
  name        = "Omni"
  description = "Self-hosted Sidero Omni (managed by the auth0 stack)"
  app_type    = "spa"

  callbacks           = [var.omni_url]
  allowed_logout_urls = [var.omni_url]
  web_origins         = [var.omni_url]
}

# Copy this once into the omni item's auth0-client-id field; omni.env
# renders from there. The value never changes for the client's lifetime.
output "omni_client_id" {
  value = auth0_client.omni.client_id
}
