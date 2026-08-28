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
| `argocd.omni.nate.cx` | `kubernetes/bootstrap/argocd/argocd-cm-oidc.yaml` (`url`) | ArgoCD UI URL via the Omni workload proxy |
| `10.16.10.100:/volume1/media` | `kubernetes/apps/*/media-pv.yaml` | NFS export holding the media library (one PV pair per consuming app) |
| `10.16.101.224/27` | `kubernetes/apps/cilium/lb-ipam.yaml` | Service VIP pool on the node VLAN, above the DHCP scope |
| `10.16.101.225` | `kubernetes/apps/plex/values.yaml` | Pinned plex VIP from the pool (LB annotation) |

This value stays in git because ArgoCD renders only committed
manifests. Everything terraform-applied arrives as TF_VAR_* instead
(Omni domain, k8s VLAN CIDR).

## 2. Values in `.example` files

`omni/omni.env.example` and `infra/**/terraform.tfvars.example` are
templates; the real files are generated (op inject) or supplied as
Spacelift TF_VAR environment variables and never committed.

## 3. Values outside git

- 1Password `homelab` vault items: see docs/BOOTSTRAP.md for the full
  item list.
- Spacelift stack environment (TF_VAR_*): set on the admin stack, fanned
  out through the homelab context; `infra/spacelift/terraform.tfvars.example`
  is the full list (includes `omni_domain` and `k8s_vlan_cidr`).
- Tailscale admin console: OAuth clients (scopes and tags are fixed at
  creation and cannot be expressed in the policy file).
- Cloudflare console: API tokens only (a token cannot create itself);
  DNS records and the R2 bucket live in infra/stacks/cloudflare.
- Proxmox console: the "vGPU" PCI resource mapping (iGPU SR-IOV virtual
  functions) that the worker machine class references.
