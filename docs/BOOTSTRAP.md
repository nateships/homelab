# Bootstrap: zero to GitOps cluster

Do the stages in order. Each stage needs the stage before it.

## 0. 1Password

1. Create a vault named `homelab`. Service accounts cannot read Private vaults.
2. Create a service account: 1Password → Developer → Service Account. Give it
   read access to the `homelab` vault only. Save the `ops_...` token in your
   Private vault.
3. Create these items in the `homelab` vault:
   - `omni`: fields `account-uuid`, `admin-email`, `auth0-domain`, `auth0-client-id`
   - `proxmox`: password field = the API token from stage 1
   - `tailscale-spacelift`: password field = the Tailscale OAuth client
     secret from stage 1
   - `tailscale-terraform`: username = OAuth client ID, password = secret;
     a second OAuth client with the policy-file write scope, used by the
     tailscale stack
   - `cloudflare`: field `dns-api-token` (Zone:DNS:Edit, for certbot)
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
   Point a DNS A record for that domain at the LXC IP.
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

Auth0 is code too (`infra/stacks/auth0`). One-time preparation:

1. Create an Auth0 tenant (free plan).
2. Create an M2M application authorized for the **Auth0 Management API**
   with the client scopes (`read:clients`, `create:clients`,
   `update:clients`, `delete:clients`). Store it in the `auth0-terraform`
   item: client ID as username, secret as password, and the tenant domain
   as the website field (the domain stays out of this public repo).
3. Set the same tenant domain in the `omni` item's `auth0-domain` field.
4. Confirm the `homelab-auth0` run. Copy the `omni_client_id` output into
   the `omni` item's `auth0-client-id` field (a one-time copy; the ID
   never changes).

Check the result: open `https://<your domain>`. Log in through Auth0 with
the admin email.

## 4. Proxmox infra provider and cluster

1. Omni UI → Infrastructure Providers → Create Provider. Copy the key. This
   is an **infrastructure provider key**, not a service account key. Store
   it as the password of the `omni-infra-provider` item.
2. Re-run `homelab-omni-config`. It deploys the
   [provider container](https://github.com/siderolabs/omni-infra-provider-proxmox)
   next to Omni, configured from 1Password.
3. Run `mise install`. It installs `omnictl` at the same version as
   `OMNI_IMG_TAG`. A version mismatch causes obscure gRPC errors. Bump
   mise.toml and omni.env together.
4. Apply machine classes and the cluster template:
   ```bash
   omnictl apply -f omni/machine-classes/control-plane.yaml
   omnictl apply -f omni/machine-classes/worker.yaml
   omnictl cluster template sync -v -f omni/cluster-template/cluster.yaml
   ```
   The `install-disk` patch in the template is mandatory on Talos 1.13+.
   Without it, VMs stop at `stage=UPGRADING` and show no error.
5. Wait until the VMs provision and the cluster reports Ready. Nodes stay
   `NotReady` until Cilium installs in stage 5. That is expected.

## 5. ArgoCD and apps

```bash
# kubeconfig via Omni
omnictl kubeconfig --cluster homelab

kubectl apply -k kubernetes/bootstrap/argocd
kubectl apply -f kubernetes/bootstrap/root.yaml

# The one manual k8s secret: 1Password service account token for ESO
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -
kubectl -n external-secrets create secret generic onepassword-service-account \
  --from-literal=token='ops_...'
```

The root app syncs `kubernetes/apps/` in this order: Cilium (wave -10), then
external-secrets and its ClusterSecretStore (wave -5), then everything you add
later.

To add a secret after this point: put an item in the `homelab` vault, then
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
