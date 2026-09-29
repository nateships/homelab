# Omni etcd backup target: Cloudflare R2 (S3-compatible). Instance-wide
# singleton; the per-cluster schedule is backup_interval on the cluster.
# The cloudflare stack owns the bucket (same r2_bucket TF_VAR); the R2
# API token and account id live in the cloudflare-r2 item. R2 ignores
# the region; "auto" is the documented value.
data "onepassword_item" "cloudflare_r2" {
  vault = data.onepassword_vault.homelab.uuid
  title = "cloudflare-r2"
}

locals {
  # Custom fields by label. The account id is not a secret; keeping it
  # readable keeps the endpoint visible in plans.
  cloudflare_r2 = {
    for f in flatten([for s in data.onepassword_item.cloudflare_r2.section : s.field]) :
    f.label => f.value
  }
}

resource "omni_etcd_backup_s3_config" "r2" {
  bucket   = var.r2_bucket
  region   = "auto"
  endpoint = "https://${nonsensitive(local.cloudflare_r2["account-id"])}.r2.cloudflarestorage.com"

  access_key_id     = data.onepassword_item.cloudflare_r2.username
  secret_access_key = data.onepassword_item.cloudflare_r2.password
}
