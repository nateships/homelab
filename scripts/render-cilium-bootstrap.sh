#!/bin/sh
# Renders the Cilium bootstrap manifest that Omni applies one time at
# cluster bootstrap (infra/stacks/cluster). ArgoCD adopts Cilium afterward
# (kubernetes/apps/cilium) and owns upgrades; keep the version and values
# here in step with that Application.
set -eu

# renovate: datasource=helm registryUrl=https://helm.cilium.io depName=cilium
VERSION=1.18.1
OUT="$(dirname "$0")/../infra/stacks/cluster/manifests/cilium-bootstrap.yaml"

helm template cilium cilium \
  --repo https://helm.cilium.io \
  --version "$VERSION" \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=7445 \
  --set 'securityContext.capabilities.ciliumAgent={CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}' \
  --set 'securityContext.capabilities.cleanCiliumState={NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}' \
  --set hubble.enabled=false \
  --set cgroup.autoMount.enabled=false \
  --set cgroup.hostRoot=/sys/fs/cgroup \
  > "$OUT"

echo "rendered $OUT"

# Refuse to emit secrets: helm-generated TLS material must never land in git.
if grep -q "kind: Secret" "$OUT"; then
  echo "ERROR: rendered manifest contains a Secret" >&2
  exit 1
fi
