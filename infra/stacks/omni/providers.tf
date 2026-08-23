# The provider reads PROXMOX_VE_ENDPOINT and PROXMOX_VE_API_TOKEN from
# the Spacelift context environment. Runs reach the LAN through the
# Tailscale SOCKS proxy; SSH does not traverse it, so this stack uses
# API-only resources (no ssh block, no file uploads).
provider "proxmox" {
  insecure = var.proxmox_insecure
}
