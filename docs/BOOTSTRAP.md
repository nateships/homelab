# Bootstrap: zero to GitOps cluster

Do the stages in order. Each stage needs the stage before it.

## 0. 1Password

1. Create a vault named `homelab`. Service accounts cannot read Private vaults.
2. Create a service account (`homelab-rw`): 1Password → Developer →
   Service Account. Give it read and write access to the `homelab`
   vault only (the tailscale stack writes minted secrets into items).
   Save the `ops_...` token in your Private vault.
3. Create these items in the `homelab` vault:
   - `omni`: fields `account-uuid`, `admin-email` (stage 3 adds `domain`,
     `lxc-ip`, and `tailnet-dns`; `omni.env.example` reads `tailnet-dns`)
   - `proxmox`: password field = the API token from stage 1. Three more
     fields feed the infra provider (stage 4): `lan-url` (the LAN API URL,
     for example `https://<pve-lan-ip>:8006`), `token-id`
     (`root@pam!spacelift`), `token-secret` (the token UUID)
   - `tailscale-spacelift`: created empty; the tailscale stack fills it
   - `tailscale-terraform`: username = OAuth client ID, password =
     secret. The ROOT client: the tailscale stack mints every other
     tailnet credential with it. Write scopes: **Policy File**,
     **OAuth Keys**, **Auth Keys**, **Devices Core**, **Services**;
     tags: `tag:terraform`, `tag:spacelift`, `tag:omni`, `tag:tsidp`,
     `tag:k8s-operator` (tag:terraform makes the client an OWNER of
     the minted tags via tagOwners; API callers must own a tag to
     assign it)
   - `tailscale-omni`, `tailscale-tsidp`: created empty; the tailscale
     stack fills them
   - `tsidp-omni`: see stage 3
   - `tsidp-argocd`: see stage 5 (ArgoCD OIDC login)
   - `tsidp-velero-ui`: same shape as `tsidp-argocd` (username = client
     id, password = secret, `issuer` field); register the client in tsidp
     with redirect URI `https://velero.<tailnet>.ts.net/login`
   - `tailscale-operator`: OAuth client for the Kubernetes operator
     (scopes **Auth Keys: write** and **Devices Core: write**, tag
     `tag:k8s-operator`). username = client ID, password = secret. The
     tag must exist in the tailnet policy first (the tailscale stack
     applies it).
   - `proxmox-csi`: password = the token secret of a dedicated
     `kubernetes-csi@pve!csi` API token (role CSI; the item's notes
     carry the pveum commands). The CSI plugin provisions worker
     volumes on the zpool with it.
   - `cloudflare`: field `dns-api-token` (Zone:DNS:Edit, for certbot)
   - `cloudflare-terraform`: password = an API token with Zone DNS Edit
     and Account R2 Write; the cloudflare stack manages the DNS records
     and the R2 bucket with it
   - `cloudflare-r2`: see stage 4 (etcd backups)
4. Copy the service account token to the Spacelift `bootstrap` context
   (stage 2). That is the only manual copy: the `homelab-k8s-bootstrap`
   stack creates the in-cluster secret from its run environment (stage 5),
   and CI needs no token.

> Family-plan service accounts have low API rate limits, and every
> `data` entry on an ExternalSecret is one API call per refresh. Keep
> ESO `refreshInterval` at `24h`; after rotating an item, force a
> refresh with
> `kubectl annotate externalsecret <name> force-sync=$(date +%s)`.

## 1. Proxmox and Tailscale

Spacelift workers cannot reach the LAN. Each run joins the tailnet and
connects to Proxmox at its ts.net address.

1. Install Tailscale on the Proxmox host:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   tailscale up   # note the MagicDNS name, e.g. pve.tailnet-name.ts.net
   ```
2. Create the root OAuth client (`tailscale-terraform` item; scopes and
   tags in stage 0). The tailscale stack mints the Spacelift run
   credential from it into the `tailscale-spacelift` item; the run hook
   adds `?ephemeral=true&preauthorized=true`. On a bare tailnet, add
   the tags to the policy before the console accepts the client.
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
   `infra/spacelift/terraform.tfvars.example` (that file is the full list).
3. Behavior → project globs: add `infra/stacks/**/stack.yaml` and
   `mise.toml`. Manifest changes and opentofu bumps (the stacks' tofu
   version comes from mise.toml) then trigger the admin stack. Other files
   in a stack dir trigger only that stack.
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
2. Fill the `omni` item: `domain` (the Omni FQDN), `admin-email`, and
   `lxc-ip` (the LXC's static IP, no CIDR suffix; it must match
   `omni_ct_ip`). The cloudflare stack creates the two DNS A records
   (domain + wildcard, proxy off); apply it before this stage.
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

1. The tailscale stack fills the `tailscale-omni` and `tailscale-tsidp`
   items (the LXC and tsidp join the tailnet with them). Set the
   tailnet DNS name in the `omni` item's `tailnet-dns` field.
2. Run `homelab-omni-config`. The LXC joins the tailnet and tsidp starts.
3. Open `https://tsidp.<tailnet>.ts.net` and register a client with
   redirect URI `https://<omni-domain>/oidc/consume`. Store the client ID
   (username) and secret (password) in the `tsidp-omni` item.
4. Re-run `homelab-omni-config`. Omni restarts with OIDC enabled.

Check the result: open the Omni domain from a tailnet device. Log in
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
and creates the one secret ESO needs (the 1Password token, taken from
the run environment). Nothing here is manual. The repo is public, so
ArgoCD needs no repo credential.

The ApplicationSet generates one Application per
`kubernetes/apps/<name>/config.yaml`. A config file holds the app name,
the destination namespace, and the sources; the shared sync policy lives
in the template (`kubernetes/bootstrap/argocd/appset.yaml`). To add an
app, commit a new directory with a `config.yaml`. To remove one, delete
the file; the Application and its resources go with it. ArgoCD adopts the
bootstrapped Cilium and manages itself, ApplicationSet included.

ArgoCD UI login uses tsidp directly (no Dex). One-time: open
`https://tsidp.<tailnet>.ts.net` and register a client with redirect URI
`https://argocd.<tailnet>.ts.net/auth/callback`. Fill the `tsidp-argocd`
item: username = client ID, password = client secret, and an `issuer`
field = `https://tsidp.<tailnet>.ts.net`. ESO delivers these to ArgoCD;
until then the local admin account works
(`kubectl -n argocd get secret argocd-initial-admin-secret`).

For your own kubectl access:
```bash
omnictl kubeconfig --cluster homelab
```

GitHub push webhooks (optional; without them ArgoCD polls every 3
minutes): the cloudflare stack routes the two webhook hostnames
(`TF_VAR_argocd_webhook_public_hostname`,
`TF_VAR_argocd_appset_webhook_public_hostname`) and mints the shared
secret into the `argocd-webhook` item; ESO merges it into
`argocd-secret`. One-time, after the stack applies and the CNAMEs
publish, create one repo webhook per hostname:

```bash
for h in argocd-webhook.example.com argocd-appset-webhook.example.com; do
  gh api repos/<owner>/<repo>/hooks -f name=web \
    -f "config[url]=https://$h/api/webhook" \
    -f "config[content_type]=json" \
    -f "config[secret]=$(op read op://homelab/argocd-webhook/password)" \
    -f "events[]=push"
done
```

To add a secret from here on: put an item in the `homelab` vault, then
commit an `ExternalSecret`:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: my-app
spec:
  refreshInterval: 24h           # items rotate only on tofu applies; Family-plan API quota is small
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
