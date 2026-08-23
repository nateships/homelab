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
| `tsidp.tail34eda.ts.net` -> `100.84.16.7` | `kubernetes/bootstrap/argocd/argocd-server-hostaliases.yaml` | tsidp OIDC issuer FQDN and its tailnet IP (the FQDN is public through Certificate Transparency logs) |

These two stay in git because ArgoCD renders only committed manifests:
its secret indirection covers `oidc.config` only, and `hostAliases`
cannot reference a Secret. Everything terraform-applied moved to
TF_VAR_* instead (Omni domain, k8s VLAN CIDR).

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
