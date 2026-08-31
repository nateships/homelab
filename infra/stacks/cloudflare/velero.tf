# Velero writes file-system backups of the config PVCs here. Retention
# is velero's job (backup TTL), so no lifecycle rule.
resource "cloudflare_r2_bucket" "velero" {
  account_id = local.cloudflare_account_id
  name       = "velero-backups"
}

data "cloudflare_account_api_token_permission_groups_list" "all" {
  account_id = local.cloudflare_account_id
}

locals {
  r2_item_write_id = one([
    for g in data.cloudflare_account_api_token_permission_groups_list.all.result :
    g.id if g.name == "Workers R2 Storage Bucket Item Write"
  ])
}

# R2's S3 credentials derive from an account token: the access key id
# is the token id and the secret is the sha256 of the token value.
resource "cloudflare_account_token" "velero_r2" {
  account_id = local.cloudflare_account_id
  name       = "velero-r2"
  policies = [{
    effect = "allow"
    permission_groups = [{
      id = local.r2_item_write_id
    }]
    resources = jsonencode({
      "com.cloudflare.edge.r2.bucket.${local.cloudflare_account_id}_default_${cloudflare_r2_bucket.velero.name}" = "*"
    })
  }]
}

# ESO renders these into velero's aws credentials file.
resource "onepassword_item" "velero" {
  vault = data.onepassword_vault.homelab.uuid
  title = "velero"
  # Password-category items drop the username attribute; login keeps
  # both fields ESO reads.
  category   = "login"
  username   = cloudflare_account_token.velero_r2.id
  password   = sha256(cloudflare_account_token.velero_r2.value)
  note_value = "R2 S3 credentials for velero; minted by the cloudflare stack (username = access key id, password = secret key)."
}
