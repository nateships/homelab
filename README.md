# homelab

[![ci](https://github.com/nateships/homelab/actions/workflows/ci.yaml/badge.svg)](https://github.com/nateships/homelab/actions/workflows/ci.yaml)
[![runner-image](https://github.com/nateships/homelab/actions/workflows/runner-image.yaml/badge.svg)](https://github.com/nateships/homelab/actions/workflows/runner-image.yaml)
[![Renovate](https://img.shields.io/badge/renovate-enabled-1a1f6c?logo=renovate)](.github/renovate.json5)

**Everything is a pull request.** Proxmox → [Omni](https://omni.siderolabs.com/) +
[Talos](https://www.talos.dev/) → [ArgoCD](https://argo-cd.readthedocs.io/),
with [Spacelift](https://spacelift.io/) running the OpenTofu and GitHub
Actions running the CI checks. No SSH into nodes, no kubectl apply, no
snowflakes: git is the interface to the whole rack.

![Talos](https://img.shields.io/badge/Talos-FF7300?logo=talos&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![OpenTofu](https://img.shields.io/badge/OpenTofu-FFDA18?logo=opentofu&logoColor=black)
![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?logo=argo&logoColor=white)
![Cilium](https://img.shields.io/badge/Cilium-F8C517?logo=cilium&logoColor=black)
![Tailscale](https://img.shields.io/badge/Tailscale-242424?logo=tailscale&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana_Cloud-F46800?logo=grafana&logoColor=white)
![1Password](https://img.shields.io/badge/1Password-3B66BC?logo=1password&logoColor=white)

This repo is public. It contains no secrets, encrypted or otherwise. All
secrets live in 1Password and reach each system at runtime (see
[Secrets](#secrets)). Committed site values carry a `site-specific:`
marker; [docs/SITE.md](docs/SITE.md) indexes what a fork must change.

## Highlights

- **Immutable nodes**: Talos VMs provisioned declaratively by a self-hosted
  Omni through its Proxmox infrastructure provider; machine classes and
  config patches in git, rolling updates on merge.
- **One app = one directory**: an ApplicationSet turns every
  `kubernetes/apps/<name>/config.yaml` into an ArgoCD Application. Adding an
  app is one PR with a handful of lines.
- **Push-triggered GitOps**: GitHub webhooks reach ArgoCD through a
  path-scoped Cloudflare tunnel route; merges deploy in seconds, not polls.
- **Cilium end to end**: kube-proxy replacement, Gateway-free tailnet
  ingress, LB-IPAM VIPs with L2 announcements, DSR for real client IPs, and
  tier-based network policy.
- **Secretless repo**: a single 1Password service account feeds Spacelift,
  bootstrap, and External Secrets Operator; rotation is a tofu apply.
- **Batteries-included observability**: Grafana Cloud via the k8s-monitoring
  chart, plus SNMP, PVE, UniFi, and ArgoCD exporters, log-level hygiene in
  Alloy, and alerts that page a phone through Grafana IRM.
- **Tested like software**: kubeconform, appset schema validation, tofu
  fmt/validate, and trufflehog run on every PR; Renovate keeps ~everything
  pinned and fresh.

## Architecture

```
GitHub (this repo)
  ├── Spacelift ──► OpenTofu ──► Proxmox (Omni LXC, networks)
  ├── GitHub Actions ──► lint / validate / kubeconform
  └── ArgoCD (in-cluster) ──► kubernetes/apps (ApplicationSet)

Proxmox host
  ├── LXC: Omni (self-hosted, Docker Compose) + Proxmox infra provider
  └── VMs: Talos nodes (provisioned by Omni via the Proxmox provider)
```

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

## Secrets

One source of truth: a 1Password **service account** scoped to a dedicated
`homelab` vault. It needs no Connect server.

| Consumer | How the token gets there |
|---|---|
| Spacelift | Hand-made `bootstrap` context with label `autoattach:op`; a stack opts in with `labels: [op]` in its stack.yaml |
| GitHub Actions | Not needed: CI only lints and validates |
| Kubernetes | The `homelab-k8s-bootstrap` stack creates one secret from its run environment; External Secrets Operator (`onepasswordSDK` provider) syncs the rest |

The service account token is the only bootstrap secret. Everything else
derives from it. Family-plan API quotas are small (1000 calls per day),
so ExternalSecrets refresh every 24h and force-sync on rotation.

## Tooling

[mise.toml](mise.toml) pins every tool: opentofu, omnictl, talosctl, kubectl,
kubeconform, helm, prek, and the 1Password CLI. Run `mise install` to get them. CI
installs from the same file.

Run `prek install` once to enable the git hooks
([.pre-commit-config.yaml](.pre-commit-config.yaml)): secret detection
(trufflehog), tofu fmt, kubeconform, YAML checks.

Renovate ([.github/renovate.json5](.github/renovate.json5)) updates all
version pins. Coupled pins update as one grouped PR each: Omni server +
omnictl, Talos + talosctl, Kubernetes + kubectl. To track a new pin, add a
`# renovate: datasource=... depName=...` comment above it.

## Bring-up

Follow [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) top to bottom. Order matters:
1Password → Spacelift → Proxmox LXC → Omni → Talos cluster → ArgoCD → apps.
