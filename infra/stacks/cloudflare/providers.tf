provider "onepassword" {}

# API token from the "cloudflare-terraform" item (API Credential
# category: the token lives in the credential field). Scopes: Zone DNS
# Edit and Account R2 Write.
provider "cloudflare" {
  api_token = data.onepassword_item.cloudflare_terraform.credential
}
