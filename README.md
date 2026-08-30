<h1 align="center">homelab</h1>

<p align="center"><code>git push</code> is the only admin interface.</p>

<p align="center">
  <a href="https://github.com/nateships/homelab/actions/workflows/ci.yaml"><img src="https://github.com/nateships/homelab/actions/workflows/ci.yaml/badge.svg" alt="ci"></a>
  <a href=".github/renovate.json5"><img src="https://img.shields.io/badge/renovate-enabled-1a1f6c?logo=renovate" alt="Renovate"></a>
</p>

GitOps-driven homelab: Proxmox → [Omni](https://omni.siderolabs.com/) +
[Talos](https://www.talos.dev/) → [ArgoCD](https://argo-cd.readthedocs.io/).
[Spacelift](https://spacelift.io/) runs the OpenTofu; GitHub Actions runs
the CI checks.

> This repo is public and contains no secrets, encrypted or otherwise.
> Secrets live in 1Password and reach each system at runtime (see
> [So you want to run this](#so-you-want-to-run-this)). Committed site values carry a `site-specific:`
> marker; [docs/SITE.md](docs/SITE.md) indexes what a fork must change.

## Highlights

- Immutable [Talos](https://www.talos.dev/) nodes, provisioned by a self-hosted [Omni](https://omni.siderolabs.com/): machine classes and patches in git.
- One app = one directory: an ApplicationSet turns each `config.yaml` into an ArgoCD Application.
- Merges deploy in seconds: GitHub webhooks reach ArgoCD through a path-scoped tunnel route.
- Cilium everywhere: kube-proxy replacement, LB-IPAM VIPs, DSR client IPs, tier-based network policy.
- One 1Password service account is the only bootstrap secret; everything else derives from it.
- Observability that pages a phone: Grafana Cloud, host and network exporters, IRM push.

## Stack

| Layer | Tech |
|---|---|
| Hypervisor | [Proxmox VE](https://www.proxmox.com/) (Talos VMs + the Omni LXC) |
| Cluster lifecycle | [Omni](https://omni.siderolabs.com/) (self-hosted) + its [Proxmox infra provider](https://github.com/siderolabs/omni-infra-provider-proxmox) |
| Node OS | [Talos Linux](https://www.talos.dev/): immutable, API-only, no SSH |
| Networking | [Cilium](https://cilium.io/): kube-proxy replacement, LB-IPAM + L2, DSR, network policy |
| Ingress | [Tailscale operator](https://tailscale.com/kb/1236/kubernetes-operator) (tailnet UIs) + [cloudflared](https://github.com/cloudflare/cloudflared) (public, tunnel-only) |
| GitOps | [ArgoCD](https://argo-cd.readthedocs.io/) + one ApplicationSet |
| IaC | [OpenTofu](https://opentofu.org/) on [Spacelift](https://spacelift.io/) |
| Secrets | [1Password](https://1password.com/) service account + [External Secrets Operator](https://external-secrets.io/) |
| Storage | [proxmox-csi](https://github.com/sergelogvinov/proxmox-csi-plugin) (ZFS-backed PVCs) + NFS media exports |
| Backups | [Velero](https://velero.io/) → Cloudflare R2; hourly Omni etcd snapshots → R2 |
| Observability | [Grafana Cloud](https://grafana.com/products/cloud/) via Alloy; SNMP, PVE, UniFi, ArgoCD exporters; IRM paging |
| CI / updates | GitHub Actions ([mise](https://mise.jdx.dev/)-pinned tools) + [Renovate](https://docs.renovatebot.com/) |

## Repo layout

```
infra/spacelift/    Admin stack: hydrates one Spacelift stack per infra/stacks/<name>/
infra/stacks/       One dir per OpenTofu stack; Spacelift runs each via Tailscale
  omni/             Omni LXC on Proxmox; stack.yaml = hydration manifest + overrides
omni/               Self-hosted Omni: compose file, env template, machine classes
kubernetes/
  bootstrap/        One-time ArgoCD install + the ApplicationSet
  apps/             One config.yaml per app; the ApplicationSet generates each Application
.github/workflows/  CI: tofu fmt/validate, appset schema, kubeconform; Spacelift runner image build
docs/BOOTSTRAP.md   Bring-up guide, zero to cluster
docs/SITE.md        Every site-specific value: what a fork must change
```

## So you want to run this

1. **Tools**: `mise install` gets everything pinned in [mise.toml](mise.toml);
   `prek install` enables the git hooks
   ([.pre-commit-config.yaml](.pre-commit-config.yaml): trufflehog, tofu fmt,
   kubeconform). CI installs from the same file, and Renovate keeps every pin
   fresh (add a `# renovate:` comment above a new pin to track it).
2. **One secret**: create a 1Password service account scoped to a dedicated
   `homelab` vault; it needs no Connect server. It is the only bootstrap
   secret. Spacelift holds it in a hand-made context, the
   `homelab-k8s-bootstrap` stack seeds it into the cluster, and External
   Secrets Operator syncs everything else from it at runtime.
3. **Your values**: [docs/SITE.md](docs/SITE.md) indexes every committed
   site-specific value a fork must change. Everything else arrives as
   Spacelift TF_VARs or 1Password items, never as commits.
4. **Bring-up**: follow [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) top to bottom.
   Order matters: 1Password → Spacelift → Proxmox LXC → Omni → Talos
   cluster → ArgoCD → apps.
