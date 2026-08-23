provider "onepassword" {}

# API token from the "cloudflare-terraform" item (API Credential
# category: the token lives in the credential field). Scopes: Zone DNS
# Edit and Account R2 Write.
provider "cloudflare" {
  # trimspace: a pasted token often carries a trailing newline.
  api_token = trimspace(data.onepassword_item.cloudflare_terraform.credential)
}
