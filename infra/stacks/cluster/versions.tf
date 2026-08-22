terraform {
  required_version = ">= 1.8"

  required_providers {
    omni = {
      source = "registry.terraform.io/siderolabs/omni"
      # Alpha provider; prerelease versions need an exact pin.
      version = "0.1.0-alpha.3"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "< 4.0.0"
    }
  }
}
