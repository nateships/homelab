locals {
  # renovate: datasource=github-releases depName=kubernetes/kubernetes extractVersion=^v(?<version>.+)$
  kubernetes_version = "1.36.4"
  # renovate: datasource=github-releases depName=siderolabs/talos extractVersion=^v(?<version>.+)$
  talos_version = "1.13.9"
}

data "onepassword_vault" "homelab" {
  name = "homelab"
}

data "onepassword_item" "omni" {
  vault = data.onepassword_vault.homelab.uuid
  title = "omni-service-account"
}

provider "onepassword" {}

provider "omni" {
  # Must match op://homelab/omni/domain. The provider needs the value
  # at plan time, so it arrives as a TF_VAR.
  endpoint            = "https://${var.omni_domain}"
  service_account_key = data.onepassword_item.omni.password
}

resource "omni_cluster" "homelab" {
  name               = "homelab"
  kubernetes_version = local.kubernetes_version
  talos_version      = local.talos_version

  backup_interval = "1h"

  features = {
    # Authenticated access to in-cluster UIs at <name>.omni.nate.cx,
    # via annotated Services (omni-kube-service-exposer.sidero.dev/*).
    enable_workload_proxy = true
  }
}

resource "omni_machine_set" "control_planes" {
  cluster = omni_cluster.homelab.name
  role    = "controlplane"

  machine_class = {
    name = "proxmox-control-plane"
    size = 3
  }
}

resource "omni_machine_set" "workers" {
  cluster = omni_cluster.homelab.name
  role    = "workers"

  update_strategy = {
    type            = "Rolling"
    max_parallelism = 1
  }

  machine_class = {
    name = "proxmox-worker"
    size = 3
  }
}

# Talos 1.13+ requires an explicit install disk. Without it, VMs stop
# at stage=UPGRADING with no error. Proxmox virtio-scsi is /dev/sda.
resource "omni_config_patch" "install_disk" {
  name    = "install-disk"
  cluster = omni_cluster.homelab.name

  data = yamlencode({
    machine = {
      install = {
        disk = "/dev/sda"
      }
    }
  })
}

# Cilium comes via ArgoCD; disable the default CNI and kube-proxy.
resource "omni_config_patch" "disable_default_cni" {
  name    = "disable-default-cni"
  cluster = omni_cluster.homelab.name

  data = yamlencode({
    cluster = {
      network = {
        cni = { name = "none" }
      }
      proxy = { disabled = true }
    }
  })
}

resource "omni_config_patch" "worker_labels" {
  name    = "worker-labels"
  cluster = omni_cluster.homelab.name

  selector = {
    machine_set = omni_machine_set.workers.name
  }

  data = yamlencode({
    machine = {
      nodeLabels = {
        "node-role.kubernetes.io/worker" = ""
      }
    }
  })
}

# Cilium bootstrap: the cluster ships no CNI, and ArgoCD pods cannot
# start without one. Omni applies this render one time; ArgoCD
# (kubernetes/apps/cilium) then owns upgrades. The render uses the same
# values.yaml as the Application. Keep this version equal to the app's
# chart version (Renovate groups the two pins).
data "helm_template" "cilium_bootstrap" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  # renovate: datasource=helm registryUrl=https://helm.cilium.io depName=cilium
  version      = "1.20.1"
  namespace    = "kube-system"
  kube_version = local.kubernetes_version
  values       = [file("${path.module}/../../../kubernetes/apps/cilium/values.yaml")]

  lifecycle {
    # Helm-generated TLS material must never reach the Omni manifest.
    postcondition {
      condition     = !strcontains(self.manifest, "kind: Secret")
      error_message = "Rendered Cilium bootstrap manifest contains a Secret."
    }
  }
}

resource "omni_kubernetes_manifest" "cilium_bootstrap" {
  name    = "cilium-bootstrap"
  cluster = omni_cluster.homelab.name
  mode    = "one-time"

  data = data.helm_template.cilium_bootstrap.manifest
}

resource "omni_machine_extensions" "all" {
  cluster = omni_cluster.homelab.name

  extensions = [
    # Proxmox guest IP reporting and clean shutdown.
    "siderolabs/qemu-guest-agent",
    # xe drives the iGPU SR-IOV virtual functions (machine class
    # pci_devices). Mainline i915 cannot drive Raptor Lake VFs. Do not
    # add microcode extensions: the PVE host loads microcode.
    "siderolabs/xe",
  ]
}
