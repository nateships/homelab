# Baseline hardening for every zone in the account: force HTTPS,
# refuse pre-1.2 TLS, sign the zone with DNSSEC. DNSSEC stays
# "pending" until the DS record exists at the registrar; enabling it
# here is safe and the DS step is one-time console work.
locals {
  all_zone_ids = {
    for z in data.cloudflare_zones.all.result : z.name => z.id
  }
  # One entry per setting, applied to every zone below.
  zone_settings = {
    always_use_https = "on"
    min_tls_version  = "1.2"
  }
}

resource "cloudflare_zone_setting" "hardening" {
  for_each = merge([
    for name, zone_id in local.all_zone_ids : {
      for setting, value in local.zone_settings :
      "${name}/${setting}" => {
        zone_id = zone_id
        setting = setting
        value   = value
      }
    }
  ]...)
  zone_id    = each.value.zone_id
  setting_id = each.value.setting
  value      = each.value.value
}

resource "cloudflare_zone_dnssec" "zones" {
  for_each = local.all_zone_ids
  zone_id  = each.value
  status   = "active"
}
