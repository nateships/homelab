terraform {
  required_version = ">= 1.8"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "< 1.0.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "< 4.0.0"
    }
  }
}
