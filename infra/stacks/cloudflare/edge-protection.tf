# Login brute-force limits for the two public apps, plus bot fight
# mode where it cannot break anything. The free plan allows one rate
# limiting rule per zone with a fixed 10s period/timeout.
#
# Bot fight mode is zone-wide with no exceptions on the free plan, so
# it stays OFF for the zone that carries the GitHub webhook hosts
# (webhook deliveries are bot traffic and a JS challenge breaks them).
locals {
  # site-specific: public zone names and hostname (docs/SITE.md)
  ratelimits = {
    # The whole zone is seerr; throttle its auth endpoints.
    "nateflix.media" = {
      description = "throttle seerr login attempts per source IP"
      expression  = "(starts_with(http.request.uri.path, \"/api/v1/auth/\") and http.request.method eq \"POST\")"
    }
    # birdnet shares its zone with the webhook hosts, so scope by host.
    # All POSTs, not just auth paths: the public app is read-only GETs.
    "nate.cx" = {
      description = "throttle POSTs to birdnet per source IP"
      expression  = "(http.host eq \"birds.nate.cx\" and http.request.method eq \"POST\")"
    }
  }
}

resource "cloudflare_bot_management" "seerr_zone" {
  zone_id    = local.all_zone_ids["nateflix.media"]
  fight_mode = true
}

resource "cloudflare_ruleset" "ratelimit" {
  for_each = local.ratelimits
  zone_id  = local.all_zone_ids[each.key]
  name     = "rate limits"
  kind     = "zone"
  phase    = "http_ratelimit"
  rules = [{
    description = each.value.description
    expression  = each.value.expression
    action      = "block"
    enabled     = true
    ratelimit = {
      characteristics     = ["ip.src", "cf.colo.id"]
      period              = 10
      requests_per_period = 5
      mitigation_timeout  = 10
    }
  }]
}
