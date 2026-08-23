#!/bin/sh
# Renders the Cilium bootstrap manifest that Omni applies one time at
# cluster bootstrap (infra/stacks/cluster). ArgoCD adopts Cilium afterward
# (kubernetes/apps/cilium) and owns upgrades. The values come from the same
# values.yaml the Application reads; keep the version in step with its
# targetRevision (Renovate groups the two pins).
set -eu

# renovate: datasource=helm registryUrl=https://helm.cilium.io depName=cilium
VERSION=1.18.1
OUT="$(dirname "$0")/../infra/stacks/cluster/manifests/cilium-bootstrap.yaml"
VALUES="$(dirname "$0")/../kubernetes/apps/cilium/values.yaml"

# The trailing-space trim matches the trailing-whitespace prek hook; the
# CI diff check compares this output to the hook-cleaned committed file.
helm template cilium cilium \
  --repo https://helm.cilium.io \
  --version "$VERSION" \
  --namespace kube-system \
  -f "$VALUES" \
  | sed -e 's/[[:space:]]*$//' \
  > "$OUT"

echo "rendered $OUT"

# Refuse to emit secrets: helm-generated TLS material must never land in git.
if grep -q "kind: Secret" "$OUT"; then
  echo "ERROR: rendered manifest contains a Secret" >&2
  exit 1
fi
