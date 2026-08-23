data "onepassword_vault" "homelab" {
  name = "homelab"
}

data "onepassword_item" "cloudflare_terraform" {
  vault = data.onepassword_vault.homelab.uuid
  title = "cloudflare-terraform"
}

locals {
  # The zone is the domain without its first label:
  # omni.example.com -> example.com.
  zone_name = join(".", slice(split(".", var.omni_domain), 1, length(split(".", var.omni_domain))))
  lxc_ip    = split("/", var.omni_ct_ip)[0]
}

data "cloudflare_zones" "zone" {
  name = local.zone_name
}

locals {
  zone_id = data.cloudflare_zones.zone.result[0].id
}

# Both records point at the Omni LXC: the domain itself and a wildcard
# for the workload service proxy. Proxying stays off: Omni terminates
# TLS with its own certificate.
resource "cloudflare_dns_record" "omni" {
  zone_id = local.zone_id
  name    = var.omni_domain
  type    = "A"
  content = local.lxc_ip
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "omni_wildcard" {
  zone_id = local.zone_id
  name    = "*.${var.omni_domain}"
  type    = "A"
  content = local.lxc_ip
  ttl     = 300
  proxied = false
}
