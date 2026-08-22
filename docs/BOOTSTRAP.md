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
   - `tailscale-spacelift`: password field = the Tailscale auth key from stage 1
   - `cloudflare`: field `dns-api-token` (Zone:DNS:Edit, for certbot)
4. Copy the service account token to three places:
   - GitHub repo secret `OP_SERVICE_ACCOUNT_TOKEN`
   - The Spacelift `bootstrap` context (stage 2)
   - One Kubernetes secret (stage 6)

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
2. Create a Tailscale auth key: admin console → Settings → Keys → **Auth key**.
   Make it reusable and ephemeral. Tag it `tag:spacelift`. In your ACLs, let
   that tag reach only the PVE host on port 8006. Store the key in the
   `tailscale-spacelift` item.
3. Create the Proxmox API token:
   ```bash
   pveum user token add root@pam spacelift --privsep=0
   ```
   Only root can set LXC `features` (nesting, keyctl), so the token must be on
   `root@pam`. Store `root@pam!spacelift=<uuid>` in the `proxmox` item.
4. Download an LXC template on the node:
   ```bash
   pveam update && pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst
   ```

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
   Set env:
   - `TF_VAR_proxmox_endpoint` = `https://pve.tailnet-name.ts.net:8006`
   - `TF_VAR_shared_tfvars` = HCL map of non-secret vars (see
     `infra/spacelift/terraform.tfvars.example`)
3. Behavior → project globs: add `infra/stacks/**/stack.yaml`. Manifest
   changes then trigger the admin stack. Other files in a stack dir trigger
   only that stack.
4. Trigger a run. The run creates the `homelab` space, the `homelab` context
   (Proxmox and Tailscale credentials, run hooks, label `autoattach:homelab`),
   and the `homelab-omni` stack (label `homelab`).
5. Confirm the `homelab-omni` run. The run creates the Omni LXC.

## 3. Omni LXC post-provision

Run these once on the Proxmox host. OpenTofu cannot set them.

```bash
# TUN device for SideroLink (userspace WireGuard)
pct set 200 --dev0 path=/dev/net/tun
pct reboot 200
```

Inside the LXC (`pct enter 200`):

```bash
# Docker
curl -fsSL https://get.docker.com | sh

# Certbot from apt, not snap (snapd is unreliable in unprivileged LXCs)
apt-get install -y certbot python3-certbot-dns-cloudflare gpg

# Cloudflare DNS challenge cert
op read "op://homelab/cloudflare/dns-api-token" # or paste by hand
cat > /root/cloudflare.ini <<'EOF'
dns_cloudflare_api_token = <token>
EOF
chmod 600 /root/cloudflare.ini
certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials /root/cloudflare.ini \
  -d omni.example.com --agree-tos -m you@example.com -n
```

## 4. Deploy Omni

Inside the LXC:

```bash
# Etcd encryption key (no passphrase); back the .asc up to 1Password
gpg --quick-generate-key "Omni (etcd encryption) <you@example.com>" rsa4096 cert never
FPR=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/ {print $10; exit}')
gpg --quick-add-key "$FPR" rsa4096 encr never
mkdir -p /etc/omni /etc/etcd /etc/omni/sqlite
gpg --export-secret-key --armor you@example.com > /etc/omni/omni.asc
chmod 600 /etc/omni/omni.asc
chown -R 1000:1000 /etc/etcd && chmod 700 /etc/etcd

# Config + start (clone repo or copy omni/ dir over)
cd omni
op inject -i omni.env.example -o omni.env   # or fill by hand
docker compose up -d
```

Check the result: open `https://omni.example.com`. Log in through Auth0 with
the admin email.

## 5. Proxmox infra provider and cluster

1. Omni UI → Infrastructure Providers → Create Provider. Copy the key. This is
   an **infrastructure provider key**, not a service account key. Store it in
   1Password.
2. Run the [omni-infra-provider-proxmox](https://github.com/siderolabs/omni-infra-provider-proxmox)
   container in the same LXC. Point it at Omni and the Proxmox API.
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
   `NotReady` until Cilium installs in stage 6. That is expected.

## 6. ArgoCD and apps

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
