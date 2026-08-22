# Credentials come from the Spacelift context as environment variables:
#   PROXMOX_VE_ENDPOINT   e.g. https://pve.tailnet-name.ts.net:8006 (via Tailscale)
#   PROXMOX_VE_API_TOKEN  e.g. root@pam!spacelift=xxxx-xxxx
# The bpg provider reads both from the environment, so nothing sensitive
# appears in this file or in tfvars. Spacelift runs reach the LAN through a
# userspace Tailscale SOCKS proxy (ALL_PROXY, set by the shared context);
# HTTP API calls traverse it, raw SSH would not, so this stack sticks to
# API-only resources (no ssh {} block, no file uploads to the node).
provider "proxmox" {
  insecure = var.proxmox_insecure
}
