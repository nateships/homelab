# Admin stack: manages all other Spacelift stacks, contexts, and env vars.
# Hand-made Spacelift objects, total: this stack (labeled "op") and the
# "bootstrap" context (OP_SERVICE_ACCOUNT_TOKEN, labeled "autoattach:op").
# Context attachment is label-driven:
#   autoattach:homelab (managed context: Proxmox + Tailscale + shared TF_VARs)
#     -> every hydrated stack, via the baseline "homelab" label
#   autoattach:op (hand-made context: 1Password token)
#     -> opt-in per stack via `labels: [op]` in its stack.yaml

# ------------------------------------------------------------------------------
# Secrets from 1Password (expects an item "proxmox" with the API token in
# its password field)
# ------------------------------------------------------------------------------
data "onepassword_vault" "homelab" {
  name = var.op_vault
}

data "onepassword_item" "proxmox" {
  vault = data.onepassword_vault.homelab.uuid
  title = "proxmox"
}

# OAuth client secret (scope auth_keys, tag tag:spacelift); does not expire.
# The run hook appends ?ephemeral=true&preauthorized=true (see docs/BOOTSTRAP.md).
data "onepassword_item" "tailscale" {
  vault = data.onepassword_vault.homelab.uuid
  title = "tailscale-spacelift"
}

# Non-secret site values (addresses, names, the SSH public key), one
# field per value. Sourcing them here leaves OP_SERVICE_ACCOUNT_TOKEN
# as the only env var the admin stack needs.
data "onepassword_item" "site" {
  vault = data.onepassword_vault.homelab.uuid
  title = "spacelift-site"
}

locals {
  # API token lives in the item's password field: root@pam!spacelift=<uuid>
  proxmox_api_token  = data.onepassword_item.proxmox.password
  tailscale_auth_key = data.onepassword_item.tailscale.password
  # field label -> value, across the item's sections. The provider
  # marks every field value sensitive; these are non-secret site
  # values, and a sensitive-derived map cannot drive for_each.
  site = {
    for f in flatten([for s in data.onepassword_item.site.section : s.field]) :
    f.label => nonsensitive(f.value)
  }
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

  # Spacelift workers have no LAN route; these hooks join each run to
  # the tailnet. Userspace tailscaled serves SOCKS5 and HTTP proxies;
  # ALL_PROXY/HTTPS_PROXY point clients at them. Each phase can run in
  # a fresh container, so every phase starts the daemon. Spacelift
  # joins hooks with &&, so the backgrounded daemon needs a subshell.
  before_init    = local.tailscale_up
  before_plan    = local.tailscale_up
  before_apply   = local.tailscale_up
  before_destroy = local.tailscale_up
  before_perform = local.tailscale_up
}

locals {
  tailscale_up = [
    "(tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1056 --state=/tmp/tailscaled.state --socket=/tmp/tailscaled.sock >/tmp/tailscaled.log 2>&1 &)",
    # Wait for the daemon socket; a fixed sleep flakes on slow workers.
    "timeout 15 sh -c 'until [ -S /tmp/tailscaled.sock ]; do sleep 0.2; done'",
    "tailscale --socket=/tmp/tailscaled.sock up --auth-key=\"$${TAILSCALE_AUTH_KEY}?ephemeral=true&preauthorized=true\" --advertise-tags=tag:spacelift --hostname=spacelift-run --accept-routes",
  ]
}

resource "spacelift_environment_variable" "tailscale_auth_key" {
  context_id = spacelift_context.homelab.id
  name       = "TAILSCALE_AUTH_KEY"
  value      = local.tailscale_auth_key
  write_only = true
}

# tailscaled dials non-tailnet destinations directly, so the proxies
# are safe for all traffic. ALL_PROXY covers curl-style tools; Go HTTP
# clients only honor HTTPS_PROXY.
resource "spacelift_environment_variable" "all_proxy" {
  context_id = spacelift_context.homelab.id
  name       = "ALL_PROXY"
  value      = "socks5://localhost:1055"
  write_only = false
}

resource "spacelift_environment_variable" "https_proxy" {
  context_id = spacelift_context.homelab.id
  name       = "HTTPS_PROXY"
  value      = "http://localhost:1056"
  write_only = false
}

resource "spacelift_environment_variable" "proxmox_endpoint" {
  context_id = spacelift_context.homelab.id
  name       = "PROXMOX_VE_ENDPOINT"
  value      = local.site["proxmox_endpoint"]
  write_only = false
}

resource "spacelift_environment_variable" "proxmox_api_token" {
  context_id = spacelift_context.homelab.id
  name       = "PROXMOX_VE_API_TOKEN"
  value      = local.proxmox_api_token
  write_only = true
}

# Fan the admin-stack inputs out to stacks as TF_VAR_* env vars.
locals {
  shared_tfvars = {
    proxmox_node    = local.site["proxmox_node"]
    omni_ct_id      = lookup(local.site, "omni_ct_id", "200")
    omni_ct_ip      = local.site["omni_ct_ip"]
    omni_ct_gateway = local.site["omni_ct_gateway"]
    omni_ct_vlan    = lookup(local.site, "omni_ct_vlan", null)
    omni_domain     = local.site["omni_domain"]
    k8s_vlan_cidr   = local.site["k8s_vlan_cidr"]
    r2_bucket       = local.site["r2_bucket"]

    ssh_public_key = local.site["ssh_public_key"]
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
# A directory becomes a stack only when it contains
# infra/stacks/<dir>/stack.yaml. Stack name = homelab-<dir>; the shared
# context attaches by label.
# Manifest keys (must be a non-empty YAML map):
#   description: ...
#   autodeploy: true          # default false: plan on push, apply on confirm
#   labels: [op]              # extra labels; "op" opts into the 1Password token
#   depends_on: [omni]        # run ordering; values are other stacks' dir keys
#   type: ansible             # default terraform; ansible runs playbook below
#   playbook: site.yml        # ansible only; path inside the stack dir
#   env: {NAME: value}        # plain env vars set on this stack only
#   project_globs: [omni/**]  # extra paths whose changes trigger this stack
# New stack = new directory + stack.yaml + push. The admin stack needs
# project globs "infra/stacks/**/stack.yaml" and "mise.toml".
# ------------------------------------------------------------------------------
locals {
  stacks_dir      = "${path.module}/../stacks"
  stack_manifests = fileset(local.stacks_dir, "**/stack.yaml")

  # The tofu version comes from the opentofu pin in mise.toml.
  tofu_version = regex("(?m)^opentofu = \"([0-9.]+)\"", file("${path.module}/../../mise.toml"))[0]

  stack_defaults = {
    description   = null
    autodeploy    = false
    labels        = []
    depends_on    = []
    type          = "terraform"
    playbook      = "site.yml"
    env           = {}
    project_globs = []
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

  name                     = "homelab-${each.key}"
  description              = each.value.description
  space_id                 = spacelift_space.homelab.id
  repository               = var.repository
  branch                   = var.branch
  project_root             = "infra/stacks/${each.value.dir}"
  terraform_workflow_tool  = each.value.type == "ansible" ? null : "OPEN_TOFU"
  terraform_version        = each.value.type == "ansible" ? null : local.tofu_version
  autodeploy               = each.value.autodeploy
  runner_image             = var.runner_image
  additional_project_globs = each.value.project_globs

  dynamic "ansible" {
    for_each = each.value.type == "ansible" ? [each.value.playbook] : []
    content {
      playbook = ansible.value
    }
  }

  # Baseline "homelab" pulls in the managed context (Proxmox + Tailscale);
  # manifest labels add more (e.g. "op" for the 1Password token).
  labels = concat(["homelab"], each.value.labels)
}

# Per-stack env vars from the manifests' env maps.
locals {
  stack_envs = merge([
    for name, s in local.stacks : {
      for k, v in s.env : "${name}:${k}" => { stack = name, name = k, value = v }
    }
  ]...)
}

resource "spacelift_environment_variable" "stack_env" {
  for_each = local.stack_envs

  stack_id   = spacelift_stack.this[each.value.stack].id
  name       = each.value.name
  value      = each.value.value
  write_only = false
}

# Run ordering from the manifests' depends_on lists.
locals {
  stack_dependencies = merge([
    for name, s in local.stacks : {
      for dep in s.depends_on : "${name}->${dep}" => { child = name, parent = dep }
    }
  ]...)
}

resource "spacelift_stack_dependency" "this" {
  for_each = local.stack_dependencies

  stack_id            = spacelift_stack.this[each.value.child].id
  depends_on_stack_id = spacelift_stack.this[each.value.parent].id
}

# Head-tracking push policy: see policies/push-track-head.rego. Attaches
# to every hydrated stack through the shared label.
resource "spacelift_policy" "push_track_head" {
  space_id    = spacelift_space.homelab.id
  name        = "push-track-head"
  type        = "GIT_PUSH"
  engine_type = "REGO_V1"
  labels      = ["autoattach:homelab"]
  body        = file("${path.module}/policies/push-track-head.rego")
}
