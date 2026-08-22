terraform {
  required_version = ">= 1.8"

  required_providers {
    spacelift = {
      source  = "spacelift-io/spacelift"
      version = ">= 1.14.0, < 2.0.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = ">= 2.1.0, < 3.0.0"
    }
  }
}
