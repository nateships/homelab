# Admin stack: manages all other Spacelift stacks, contexts, and env vars.
# Hand-made Spacelift objects, total: this stack (labeled "op") and the
# "bootstrap" context (OP_SERVICE_ACCOUNT_TOKEN, labeled "autoattach:op").
# Context attachment is label-driven:
#   autoattach:homelab (managed context: Proxmox + Tailscale + shared TF_VARs)
#     -> every hydrated stack, via the baseline "homelab" label
#   autoattach:op (hand-made context: 1Password token)
#     -> opt-in per stack via `labels: [op]` in its stack.yaml

# ------------------------------------------------------------------------------
# Secrets from 1Password (expects an item "proxmox" with an "api-token" field)
# ------------------------------------------------------------------------------
data "onepassword_vault" "homelab" {
  name = var.op_vault
}

data "onepassword_item" "proxmox" {
  vault = data.onepassword_vault.homelab.uuid
  title = "proxmox"
}

# Ephemeral + reusable auth key, tagged tag:spacelift (see docs/BOOTSTRAP.md)
data "onepassword_item" "tailscale" {
  vault = data.onepassword_vault.homelab.uuid
  title = "tailscale-spacelift"
}

locals {
  # API token lives in the item's password field: root@pam!spacelift=<uuid>
  proxmox_api_token  = data.onepassword_item.proxmox.password
  tailscale_auth_key = data.onepassword_item.tailscale.password
}

# ------------------------------------------------------------------------------
# Space: everything hydrated lives here, not in root
# ------------------------------------------------------------------------------
resource "spacelift_space" "homelab" {
  name             = "homelab"
  parent_space_id  = "root"
  description      = "Homelab stacks and contexts (managed by the admin stack)"
  inherit_entities = true # root-space entities (bootstrap context) stay usable
}

# ------------------------------------------------------------------------------
# Shared context: credentials every homelab stack needs
# ------------------------------------------------------------------------------
resource "spacelift_context" "homelab" {
  space_id    = spacelift_space.homelab.id
  name        = "homelab"
  description = "Shared credentials + Tailscale connectivity for homelab stacks (managed by the admin stack)"

  # Auto-attaches to every stack labeled "homelab"; no attachment resources.
  labels = ["autoattach:homelab"]

  # Spacelift's hosted workers have no route to the LAN. These hooks join the
  # run to the tailnet: userspace tailscaled (no root, no TUN device) exposing
  # a SOCKS5 proxy that the ALL_PROXY env var (below) points Go HTTP clients
  # at. Proxmox is reached at its ts.net address. The binaries come from the
  # custom runner image (runner/Dockerfile).
  # Spacelift joins hooks with &&, so the backgrounded daemon needs a
  # subshell; a trailing bare & would produce "& &&" and a syntax error.
  before_init = [
    "(tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --state=/tmp/tailscaled.state --socket=/tmp/tailscaled.sock >/tmp/tailscaled.log 2>&1 &)",
    "sleep 2",
    "tailscale --socket=/tmp/tailscaled.sock up --auth-key=$TAILSCALE_AUTH_KEY --hostname=spacelift-run --accept-routes",
  ]
}

resource "spacelift_environment_variable" "tailscale_auth_key" {
  context_id = spacelift_context.homelab.id
  name       = "TAILSCALE_AUTH_KEY"
  value      = local.tailscale_auth_key
  write_only = true
}

# tailscaled's netstack dials non-tailnet destinations directly, so routing
# everything through the SOCKS proxy is safe (registry downloads included).
resource "spacelift_environment_variable" "all_proxy" {
  context_id = spacelift_context.homelab.id
  name       = "ALL_PROXY"
  value      = "socks5://localhost:1055"
  write_only = false
}

resource "spacelift_environment_variable" "proxmox_endpoint" {
  context_id = spacelift_context.homelab.id
  name       = "PROXMOX_VE_ENDPOINT"
  value      = var.proxmox_endpoint
  write_only = false
}

resource "spacelift_environment_variable" "proxmox_api_token" {
  context_id = spacelift_context.homelab.id
  name       = "PROXMOX_VE_API_TOKEN"
  value      = local.proxmox_api_token
  write_only = true
}

# Fan the individual admin-stack inputs out to stacks as TF_VAR_* env vars.
locals {
  shared_tfvars = {
    proxmox_node    = var.proxmox_node
    omni_ct_ip      = var.omni_ct_ip
    omni_ct_gateway = var.omni_ct_gateway
    omni_ct_vlan    = var.omni_ct_vlan == null ? null : tostring(var.omni_ct_vlan)
    ssh_public_key  = var.ssh_public_key
  }
}

resource "spacelift_environment_variable" "shared_tfvars" {
  for_each = { for k, v in local.shared_tfvars : k => v if v != null }

  context_id = spacelift_context.homelab.id
  name       = "TF_VAR_${each.key}"
  value      = each.value
  write_only = false
}

# ------------------------------------------------------------------------------
# Stacks: auto-hydrated from stack.yaml manifests
#
# A directory becomes a stack only when it contains infra/stacks/<dir>/stack.yaml
# (explicit opt-in: shared-module or WIP dirs never hydrate by accident).
# Stack name = homelab-<dir path, / replaced by ->, shared context attached.
# Manifest keys (must be a non-empty YAML map):
#   description: ...
#   autodeploy: true          # default false: plan on push, apply on confirm
#   labels: [op]              # extra labels; "op" opts into the 1Password token
# Adding a stack = new directory + stack.yaml + push. Note: the admin stack
# must have project glob "infra/stacks/**/stack.yaml" set so manifest
# changes trigger it.
# ------------------------------------------------------------------------------
locals {
  stacks_dir      = "${path.module}/../stacks"
  stack_manifests = fileset(local.stacks_dir, "**/stack.yaml")

  stack_defaults = {
    description = null
    autodeploy  = false
    labels      = []
  }

  stacks = {
    for f in local.stack_manifests :
    replace(dirname(f), "/", "-") => merge(
      local.stack_defaults,
      { dir = dirname(f) },
      yamldecode(file("${local.stacks_dir}/${f}"))
    )
  }
}

resource "spacelift_stack" "this" {
  for_each = local.stacks

  name                    = "homelab-${each.key}"
  description             = each.value.description
  space_id                = spacelift_space.homelab.id
  repository              = var.repository
  branch                  = var.branch
  project_root            = "infra/stacks/${each.value.dir}"
  terraform_workflow_tool = "OPEN_TOFU"
  autodeploy              = each.value.autodeploy
  runner_image            = var.runner_image

  # Baseline "homelab" pulls in the managed context (Proxmox + Tailscale);
  # manifest labels add more (e.g. "op" for the 1Password token).
  labels = concat(["homelab"], each.value.labels)
}
