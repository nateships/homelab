# Baseline hardening for every zone in the account: force HTTPS,
# refuse pre-1.2 TLS, sign the zone with DNSSEC. DNSSEC stays
# "pending" until the DS record exists at the registrar; enabling it
# here is safe and the DS step is one-time console work.
locals {
  all_zone_ids = {
    for z in data.cloudflare_zones.all.result : z.name => z.id
  }
}

resource "cloudflare_zone_setting" "always_use_https" {
  for_each   = local.all_zone_ids
  zone_id    = each.value
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "min_tls_version" {
  for_each   = local.all_zone_ids
  zone_id    = each.value
  setting_id = "min_tls_version"
  value      = "1.2"
}

resource "cloudflare_zone_dnssec" "zones" {
  for_each = local.all_zone_ids
  zone_id  = each.value
  status   = "active"
}
