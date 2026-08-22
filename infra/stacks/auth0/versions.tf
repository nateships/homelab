terraform {
  required_version = ">= 1.8"

  required_providers {
    auth0 = {
      source  = "auth0/auth0"
      version = ">= 1.0.0, < 2.0.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "< 4.0.0"
    }
  }
}
