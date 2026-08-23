# Bootstrap: zero to GitOps cluster

Do the stages in order. Each stage needs the stage before it.

## 0. 1Password

1. Create a vault named `homelab`. Service accounts cannot read Private vaults.
2. Create a service account: 1Password → Developer → Service Account. Give it
   read access to the `homelab` vault only. Save the `ops_...` token in your
   Private vault.
3. Create these items in the `homelab` vault:
   - `omni`: fields `account-uuid`, `admin-email`
   - `proxmox`: password field = the API token from stage 1
   - `tailscale-spacelift`: password field = the Tailscale OAuth client
     secret from stage 1
   - `tailscale-terraform`: username = OAuth client ID, password = secret;
     a second OAuth client with the policy-file write scope, used by the
     tailscale stack
   - `tailscale-omni`, `tailscale-tsidp`, `tsidp-omni`: see stage 3
   - `tsidp-argocd`: see stage 5 (ArgoCD OIDC login)
   - `tailscale-operator`: OAuth client for the Kubernetes operator
     (scopes **Auth Keys: write** and **Devices Core: write**, tag
     `tag:k8s-operator`). username = client ID, password = secret. The
     tag must exist in the tailnet policy first (the tailscale stack
     applies it).
   - `cloudflare`: field `dns-api-token` (Zone:DNS:Edit, for certbot)
   - `cloudflare-r2`: see stage 4 (etcd backups)
   - `github-argocd`: fields `app-id` and `installation-id` of a GitHub App.
     Create it under Settings → Developer settings → GitHub Apps: permission
     Contents: Read-only, webhook off, install on `nateships/homelab` only
     (the installation id is in the installation page URL). Store the App
     private key (PEM) as a document named `github-argocd-key`. ArgoCD
     reads the private repo with it. TODO(public): remove the App, both
     1Password entries, and the bootstrap task that consumes them.
4. Copy the service account token to three places:
   - GitHub repo secret `OP_SERVICE_ACCOUNT_TOKEN`
   - The Spacelift `bootstrap` context (stage 2)
   - One Kubernetes secret (stage 5)

> Family-plan service accounts have low API rate limits. Keep ESO
> `refreshInterval` at `1h` on each ExternalSecret.

## 1. Proxmox and Tailscale

Spacelift workers cannot reach the LAN. Each run joins the tailnet and
connects to Proxmox at its ts.net address.

1. Install Tailscale on the Proxmox host:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   tailscale up   # note the MagicDNS name, e.g. pve.tailnet-name.ts.net
   ```
2. Create a Tailscale OAuth client for Spacelift runs. First add the tag to
   your ACLs and let it reach only the PVE host on port 8006:
   ```jsonc
   "tagOwners": { "tag:spacelift": ["autogroup:admin"] },
   "acls": [{ "action": "accept", "src": ["tag:spacelift"], "dst": ["pve1:8006"] }],
   ```
   Then: admin console → Settings → **OAuth clients** → Generate. Scope:
   **Keys → Auth Keys (write)**. Tag: `tag:spacelift`. Store the
   `tskey-client-...` secret in the `tailscale-spacelift` item. The secret
   does not expire; the run hook adds `?ephemeral=true&preauthorized=true`.
3. Create the Proxmox API token:
   ```bash
   pveum user token add root@pam spacelift --privsep=0
   ```
   Keep the token on `root@pam`. Note: even a root token can only set the
   `nesting` feature flag; the Ansible stack sets `keyctl` as real root.
   Store `root@pam!spacelift=<uuid>` in the `proxmox` item.

## 2. Spacelift

Manual Spacelift objects, total: one context, one stack, two env vars.
Contexts attach through `autoattach:` labels, not clicks.

1. Create context `bootstrap`. Add env `OP_SERVICE_ACCOUNT_TOKEN`
   (write-only). Add label `autoattach:op`. The context then attaches to each
   stack that has the `op` label. The token lives in one Spacelift place.
2. Create stack `root-admin-stack`: repo `nateships/homelab`, path
   `infra/spacelift`, OpenTofu. Add label `op`. Attach the built-in
   **Space Admin** role for the `root` space: Settings → Roles → Manage Roles.
   The role must target `root` because the stack creates a child space.
   Set the runner image (Behavior → Runner image) to
   `ghcr.io/nateships/spacelift-runner:latest`. It carries the op CLI that
   the 1Password provider shells out to, plus Tailscale. GitHub Actions
   builds it on push; after the first build, set the ghcr package
   visibility to public so Spacelift can pull it.
   Set one `TF_VAR_*` env for each input in
   `infra/spacelift/terraform.tfvars.example`: `proxmox_endpoint`,
   `proxmox_node`, `omni_ct_ip`, `omni_ct_gateway`, `omni_ct_vlan`
   (optional), `ssh_public_key`.
3. Behavior → project globs: add `infra/stacks/**/stack.yaml`. Manifest
   changes then trigger the admin stack. Other files in a stack dir trigger
   only that stack.
4. Trigger a run. The run creates the `homelab` space, the `homelab` context
   (Proxmox and Tailscale credentials, run hooks, label `autoattach:homelab`),
   and the `homelab-omni` stack (label `homelab`).
5. Confirm the `homelab-omni` run. The run creates the Omni LXC.

## 3. Omni deployment (the Ansible stack)

The `homelab-omni-config` stack configures the container and deploys Omni.
It connects to the PVE host with Tailscale SSH and does all container work
through `pct`. Secrets render on the runner with `op`; nothing is stored
outside 1Password. Re-run the stack to deploy config or image changes
(for example a Renovate bump of `OMNI_IMG_TAG`).

One-time preparation:

1. Enable Tailscale SSH on the PVE host: `tailscale set --ssh`
2. Fill the `omni` item: `domain` (the Omni FQDN) and `admin-email`.
   Point two DNS A records at the LXC IP: the domain itself and a
   wildcard (`*.` prefix) for the workload service proxy. Proxy off.
3. Fill `cloudflare/dns-api-token` (Zone:DNS:Edit) for the certbot
   DNS challenge.
4. Generate the etcd encryption key locally and store it in 1Password:
   ```bash
   gpg --quick-generate-key "Omni (etcd encryption) <you@example.com>" rsa4096 cert never
   FPR=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/ {print $10; exit}')
   gpg --quick-add-key "$FPR" rsa4096 encr never
   gpg --export-secret-key --armor you@example.com > omni.asc
   op document create omni.asc --vault homelab --title omni-gpg
   rm omni.asc
   ```
   Keep the key in your GPG keyring too; without it, etcd data is
   unrecoverable.
5. Trigger `homelab-omni-config` and confirm the run.

Login uses Tailscale identity through tsidp (an OIDC provider that runs
next to Omni and joins the tailnet). Two-phase, because the OIDC client can
only be registered once tsidp runs:

1. Create two more Tailscale OAuth clients (Trust credentials, scope
   **Auth keys: write**): one with tag `tag:omni` (the LXC joins the
   tailnet), one with `tag:tsidp`. Store the secrets in the
   `tailscale-omni` and `tailscale-tsidp` items. Set the tailnet DNS name
   in the `tailscale-tsidp` item's `tailnet-dns` field.
2. Run `homelab-omni-config`. The LXC joins the tailnet and tsidp starts.
3. Open `https://tsidp.<tailnet>.ts.net` and register a client with
   redirect URI `https://omni.nate.cx/oidc/consume`. Store the client ID
   (username) and secret (password) in the `tsidp-omni` item.
4. Re-run `homelab-omni-config`. Omni restarts with OIDC enabled.

Check the result: open `https://omni.nate.cx` from a tailnet device. Log in
with your Tailscale identity. `admin-email` in the `omni` item must match
the email tsidp presents; if login fails, compare with the login screen and
update the field, then re-run the stack.

## 4. Proxmox infra provider and cluster

1. Omni UI → Infrastructure Providers → Create Provider (id `proxmox`).
   Copy the key. This is an **infrastructure provider key**, not a service
   account key. Store it as the password of the `omni-infra-provider` item.
2. Omni UI → Settings → Service Accounts → create one with the Admin role.
   Store the key as the password of the `omni-service-account` item.
3. Re-run `homelab-omni-config`. It deploys the
   [provider container](https://github.com/siderolabs/omni-infra-provider-proxmox)
   next to Omni, configured from 1Password.
4. Create the etcd backup target in Cloudflare R2:
   - R2 → Create bucket, for example `omni-etcd-backups`.
   - R2 → Manage R2 API Tokens → Create. Permission **Object Read & Write**,
     scoped to that bucket only.
   - Fill the `cloudflare-r2` item: `bucket`, `account-id` (from the R2
     endpoint), username = Access Key ID, password = Secret Access Key.
   Omni encrypts each backup with a per-cluster key before upload, so R2
   never holds plaintext cluster data. The key lives in Omni's database;
   backups are only restorable through Omni.
5. Confirm the `homelab-omni-resources` run. It applies the machine classes
   and the etcd backup configuration with omnictl. Omni validates the R2
   credentials by listing the bucket.
6. Confirm the `homelab-cluster` run. It creates the cluster, machine sets,
   config patches, extensions, and the one-time Cilium bootstrap manifest.
   The `install-disk` patch is mandatory on Talos 1.13+; without it VMs stop
   at `stage=UPGRADING` and show no error.
7. Wait until the VMs provision and the cluster reports Ready in Omni.
   Automatic etcd backups start when the cluster is Ready; the cluster
   stack sets a 1 hour interval. Check: Omni UI → cluster → Backups.

## 5. ArgoCD and apps

Confirm the `homelab-k8s-bootstrap` run. It fetches a service-account
kubeconfig from Omni, installs ArgoCD together with the ApplicationSet,
creates the repo credential (`github-argocd`), and creates the one secret
ESO needs (the 1Password token, taken from the run environment). Nothing
here is manual.

The ApplicationSet generates one Application per
`kubernetes/apps/<name>/config.yaml`. A config file holds the app name,
the destination namespace, and the sources; the shared sync policy lives
in the template (`kubernetes/bootstrap/argocd/appset.yaml`). To add an
app, commit a new directory with a `config.yaml`. To remove one, delete
the file; the Application and its resources go with it. ArgoCD adopts the
bootstrapped Cilium and manages itself, ApplicationSet included.

ArgoCD UI login uses tsidp directly (no Dex). One-time: open
`https://tsidp.<tailnet>.ts.net` and register a client with redirect URI
`https://argocd.omni.nate.cx/auth/callback`. Fill the `tsidp-argocd`
item: username = client ID, password = client secret, and an `issuer`
field = `https://tsidp.<tailnet>.ts.net`. ESO delivers these to ArgoCD;
until then the local admin account works
(`kubectl -n argocd get secret argocd-initial-admin-secret`).

For your own kubectl access:
```bash
omnictl kubeconfig --cluster homelab
```

To add a secret from here on: put an item in the `homelab` vault, then
commit an `ExternalSecret`:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: my-app
spec:
  refreshInterval: 1h            # keep >= 1h: Family-plan rate limits
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: my-app
  data:
    - secretKey: password
      remoteRef:
        key: my-app              # 1Password item name
        property: password       # field name
```

## Known gotchas

- Docker in LXC needs `nesting` and `keyctl`. The OpenTofu config sets both.
- ZFS older than 2.2 breaks Docker overlay2 in an LXC rootfs. Proxmox 8.x
  ships a new enough ZFS.
- A Proxmox host reboot takes Omni down. Talos nodes tolerate this, but you
  cannot manage the cluster until the LXC is back.
- Talos VMs must reach WireGuard UDP `:50180` on the Omni LXC. A bridged
  vmbr0 network is enough.
- Keep `omnictl` and the Omni server on the same release.
