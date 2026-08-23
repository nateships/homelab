terraform {
  required_version = ">= 1.8"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.0.0, < 6.0.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "< 4.0.0"
    }
  }
}
