provider "onepassword" {}

# API token from the "cloudflare-terraform" item (API Credential
# category: the token lives in the credential field). Scopes: Zone DNS
# Write, Zone Settings Write, DNSSEC Write, Zone WAF Write, Bot
# Management Write, Account R2 Write, Account API Tokens Write,
# Account Notification Services Write.
provider "cloudflare" {
  api_token = data.onepassword_item.cloudflare_terraform.credential
}
