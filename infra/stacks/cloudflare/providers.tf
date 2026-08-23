provider "onepassword" {}

# API token from the "cloudflare-terraform" item: scopes Zone DNS Edit
# and Account R2 Write.
provider "cloudflare" {
  api_token = data.onepassword_item.cloudflare_terraform.password
}
