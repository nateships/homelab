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
| `omni.nate.cx` | `infra/stacks/cluster/main.tf` (provider endpoint) | Omni domain |
| `argocd.omni.nate.cx` | `kubernetes/bootstrap/argocd/argocd-cm-oidc.yaml` (`url`) | ArgoCD UI URL via the Omni workload proxy |
| `tsidp.tail34eda.ts.net` -> `100.84.16.7` | `kubernetes/bootstrap/argocd/argocd-server-hostaliases.yaml` | tsidp OIDC issuer FQDN and its tailnet IP (the FQDN is public through Certificate Transparency logs) |
| `10.16.101.0/24` | `infra/stacks/tailscale/policy.hujson` (autoApprovers) | k8s VLAN CIDR the PVE host advertises |
| whole file | `infra/stacks/tailscale/policy.hujson` | The tailnet policy is site-specific by nature |

## 2. Values in `.example` files

`omni/omni.env.example` and `infra/**/terraform.tfvars.example` are
templates; the real files are generated (op inject) or supplied as
Spacelift TF_VAR environment variables and never committed.

## 3. Values outside git

- 1Password `homelab` vault items: see docs/BOOTSTRAP.md for the full
  item list.
- Spacelift stack environment (TF_VAR_*): set by the admin stack.
- Tailscale admin console: OAuth clients (scopes and tags are fixed at
  creation and cannot be expressed in the policy file).
