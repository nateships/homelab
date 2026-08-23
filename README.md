# homelab

GitOps-driven homelab: Proxmox → Omni + Talos → ArgoCD. Spacelift runs the
OpenTofu. GitHub Actions runs the CI checks.

This repo is written to go **public**. It contains no secrets, encrypted or
otherwise. All secrets live in 1Password and reach each system at runtime
(see [Secrets](#secrets)). Private-repo plumbing carries a `TODO(public)`
marker and dies when the repo opens.

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
.github/workflows/  CI: tofu fmt/validate, kubeconform
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
derives from it. Family-plan rate limits are low, so keep the ESO refresh
interval at 1h.

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
