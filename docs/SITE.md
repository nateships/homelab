# Site-specific values

This repo is public and mostly agnostic. Everything a fork must change
falls into three layers. Nothing in git is a secret: secrets live in
1Password and reach the cluster through ESO, Spacelift contexts, and
plan-time `op` reads.

## 1. Values committed in git

Every committed site value carries a `site-specific:` marker comment.
Find them all with:

```sh
grep -rn "site-specific:" --include="*.yaml" --include="*.tf" --include="*.hujson" .
```

| Value | Where | Meaning |
|---|---|---|
| `argocd.tail34eda.ts.net` | `kubernetes/bootstrap/argocd/argocd-cm-oidc.yaml` (`url`) | ArgoCD UI tailnet name (tailscale ingress) |
| `*.tail34eda.ts.net` | `kubernetes/apps/*/config.yaml` (`url`) | App UI tailnet hostnames; the ApplicationSet turns them into ArgoCD launch-icon links |
| `10.16.10.100:/volume1/media` | `kubernetes/apps/*/media-pv.yaml` | NFS export holding the media library (one PV pair per consuming app) |
| `10.16.10.100:/volume1/birdnet` | `kubernetes/apps/birdnet-go/birdnet-pv.yaml` | NFS export holding the bird clip library |
| `birds.nate.cx` | `kubernetes/apps/birdnet-go/values.yaml` (`ingress.public`) | Public hostname; the cloudflare-tunnel controller reads it to make the route and DNS |
| `nateflix.media` | `kubernetes/apps/seerr/values.yaml` (`ingress.public`) | Public hostname for seerr; cloudflare-tunnel controller route and DNS |
| `nateflix.media`, `nate.cx`, `birds.nate.cx` | `infra/stacks/cloudflare/edge-protection.tf` | Zone/host names the login rate limits and bot fight mode attach to |
| `argocd-webhook.nate.cx` | `kubernetes/bootstrap/argocd/webhook-ingress.yaml` | Public GitHub webhook host for argocd-server; cloudflare-tunnel route and DNS |
| `argocd-appset-webhook.nate.cx` | `kubernetes/bootstrap/argocd/webhook-ingress.yaml` | Public GitHub webhook host for the applicationset controller |
| `10.16.10.55` | `kubernetes/apps/monitoring/values.yaml` (`extraConfig`) | PVE host LAN address (pve-exporter scrape target) |
| `10.16.10.100` | `kubernetes/apps/monitoring/values.yaml` (`extraConfig`) | NFS server address (snmp-exporter scrape target) |
| `10.16.101.224/27` | `kubernetes/apps/cilium/lb-ipam.yaml` | Service VIP pool on the node VLAN, above the DHCP scope |
| `10.16.101.225` | `kubernetes/apps/plex/values.yaml` | Pinned plex VIP from the pool (LB annotation) |
| R2 endpoint | `kubernetes/apps/velero/values.yaml` (`s3Url`) | Account-scoped R2 S3 endpoint for velero backups |
| `network_bridge: vmbr0`, `vlan: 101` | `omni/machine-classes/*.yaml` | PVE bridge and VLAN id the cluster VMs attach to |
| `storage_selector: name == "zpool"` | `omni/machine-classes/*.yaml` | CEL selector naming the PVE datastore for VM disks |
| `xe.force_probe=a780` | `omni/machine-classes/worker.yaml` | PCI device id of the host iGPU (xe driver probe) |
| `mapping: vGPU` | `omni/machine-classes/worker.yaml` | Name of the hand-made Proxmox PCI resource mapping |

These values stay in git because ArgoCD and Omni render only committed
manifests. Everything terraform-applied arrives as TF_VAR_* instead
(Omni domain, k8s VLAN CIDR).

## 2. Values in `.example` files

`omni/omni.env.example` is a template; the real file is generated
(op inject) and never committed.

## 3. Values outside git

- 1Password `homelab` vault items: see docs/BOOTSTRAP.md for the full
  item list. The `spacelift-site` item holds every non-secret site
  value the admin stack fans out as TF_VAR_* (addresses, names, the
  SSH public key); the stack's only env var is OP_SERVICE_ACCOUNT_TOKEN.
- Tailscale admin console: OAuth clients (scopes and tags are fixed at
  creation and cannot be expressed in the policy file).
- Cloudflare console: API tokens only (a token cannot create itself);
  DNS records and the R2 bucket live in infra/stacks/cloudflare.
- Proxmox console: the "vGPU" PCI resource mapping (iGPU SR-IOV virtual
  functions) that the worker machine class references.
