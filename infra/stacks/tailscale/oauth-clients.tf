# Every tailnet credential except the stack's own: the root
# tailscale-terraform client (union scopes, hand-made) mints these, and
# their secrets land in the 1Password items the consumers already read.
# Scope or tag changes are plan/apply; rotation is tofu taint.

resource "tailscale_oauth_client" "spacelift" {
  description = "spacelift-runs"
  scopes      = ["auth_keys"]
  tags        = ["tag:spacelift"]
}

resource "onepassword_item" "tailscale_spacelift" {
  vault    = data.onepassword_vault.homelab.uuid
  title    = "tailscale-spacelift"
  category = "password"
  password = tailscale_oauth_client.spacelift.key
}

import {
  to = onepassword_item.tailscale_spacelift
  id = "vaults/nepmh5li3casah74lu46ip74ym/items/pabhby2ddtolapziaurulpoze4"
}

resource "tailscale_oauth_client" "omni" {
  description = "omni-lxc"
  scopes      = ["auth_keys"]
  tags        = ["tag:omni"]
}

resource "onepassword_item" "tailscale_omni" {
  vault    = data.onepassword_vault.homelab.uuid
  title    = "tailscale-omni"
  category = "password"
  password = tailscale_oauth_client.omni.key
}

import {
  to = onepassword_item.tailscale_omni
  id = "vaults/nepmh5li3casah74lu46ip74ym/items/ufkc53z73p7cbvn52egxl6xf54"
}

resource "tailscale_oauth_client" "tsidp" {
  description = "tsidp"
  scopes      = ["auth_keys"]
  tags        = ["tag:tsidp"]
}

resource "onepassword_item" "tailscale_tsidp" {
  vault    = data.onepassword_vault.homelab.uuid
  title    = "tailscale-tsidp"
  category = "password"
  password = tailscale_oauth_client.tsidp.key
}

import {
  to = onepassword_item.tailscale_tsidp
  id = "vaults/nepmh5li3casah74lu46ip74ym/items/m2zbeafqxddrskjkpnkzjo3uue"
}

resource "tailscale_oauth_client" "k8s_operator" {
  description = "kubernetes-operator"
  scopes      = ["auth_keys", "devices:core", "services"]
  tags        = ["tag:k8s-operator"]
}

resource "onepassword_item" "tailscale_operator" {
  vault    = data.onepassword_vault.homelab.uuid
  title    = "tailscale-operator"
  category = "login"
  username = tailscale_oauth_client.k8s_operator.id
  password = tailscale_oauth_client.k8s_operator.key
}

import {
  to = onepassword_item.tailscale_operator
  id = "vaults/nepmh5li3casah74lu46ip74ym/items/ah7ehoka5etibodjcyxwnsnlgi"
}
