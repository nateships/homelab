# Login brute-force limits for the two public apps, plus bot fight
# mode where it cannot break anything. The free plan allows one rate
# limiting rule per zone with a fixed 10s period/timeout.
#
# Bot fight mode is zone-wide with no exceptions on the free plan, so
# it stays OFF for the zone that carries the GitHub webhook hosts
# (webhook deliveries are bot traffic and a JS challenge breaks them).

# site-specific: public zone names (docs/SITE.md)
locals {
  seerr_zone_id = local.all_zone_ids["nateflix.media"]
  birds_zone_id = local.all_zone_ids["nate.cx"]
}

resource "cloudflare_bot_management" "seerr_zone" {
  zone_id    = local.seerr_zone_id
  fight_mode = true
}

# seerr: its whole zone is the app; throttle auth endpoints.
resource "cloudflare_ruleset" "seerr_ratelimit" {
  zone_id = local.seerr_zone_id
  name    = "rate limits"
  kind    = "zone"
  phase   = "http_ratelimit"
  rules = [{
    description = "throttle seerr login attempts per source IP"
    expression  = "(starts_with(http.request.uri.path, \"/api/v1/auth/\") and http.request.method eq \"POST\")"
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

# birdnet: shares its zone with the webhook hosts, so scope by host.
# All POSTs, not just auth paths: the public app is read-only GETs.
resource "cloudflare_ruleset" "birds_ratelimit" {
  zone_id = local.birds_zone_id
  name    = "rate limits"
  kind    = "zone"
  phase   = "http_ratelimit"
  rules = [{
    # site-specific: public hostname (docs/SITE.md)
    description = "throttle POSTs to birdnet per source IP"
    expression  = "(http.host eq \"birds.nate.cx\" and http.request.method eq \"POST\")"
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
