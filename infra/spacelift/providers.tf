# Spacelift injects an API token into runs of stacks that hold the Space
# Admin role, so the provider needs no configuration here.
provider "spacelift" {}

# 1Password authenticates via the OP_SERVICE_ACCOUNT_TOKEN env var, supplied
# by the hand-made "bootstrap" context (see docs/BOOTSTRAP.md).
provider "onepassword" {}
