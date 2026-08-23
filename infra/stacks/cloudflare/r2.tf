# Omni uploads an encrypted etcd snapshot every hour
# (backup_interval on the cluster). The lifecycle rule bounds
# retention; without it the bucket grows forever.
resource "cloudflare_r2_bucket" "etcd_backups" {
  account_id = var.r2_account_id
  name       = var.r2_bucket
}

# Adopts an existing bucket when the state is fresh; inert otherwise.
# Keep it: on a disaster-recovery rebuild the bucket survives (it holds
# the backups) while the state starts empty.
import {
  to = cloudflare_r2_bucket.etcd_backups
  # Segments: account id, bucket, jurisdiction.
  id = "${var.r2_account_id}/${var.r2_bucket}/default"
}

resource "cloudflare_r2_bucket_lifecycle" "etcd_backups" {
  account_id  = var.r2_account_id
  bucket_name = cloudflare_r2_bucket.etcd_backups.name

  rules = [{
    id      = "expire-old-backups"
    enabled = true
    conditions = {
      prefix = ""
    }
    delete_objects_transition = {
      condition = {
        type    = "Age"
        max_age = 2592000 # 30 days of hourly snapshots
      }
    }
  }]
}
