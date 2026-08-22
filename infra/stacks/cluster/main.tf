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
  endpoint            = "https://omni.nate.cx"
  service_account_key = data.onepassword_item.omni.password
}

resource "omni_cluster" "homelab" {
  name               = "homelab"
  kubernetes_version = local.kubernetes_version
  talos_version      = local.talos_version

  backup_interval = "1h"
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

# MANDATORY on Talos 1.13+: the LifecycleService install/upgrade flow needs
# an explicit install disk. Without it, VMs stop at stage=UPGRADING and show
# no error. Proxmox virtio-scsi presents as /dev/sda.
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

# Cilium bootstrap: the cluster ships no CNI (patch above), and ArgoCD's own
# pods cannot start without one. Omni applies this rendered chart ONE TIME at
# bootstrap; ArgoCD (kubernetes/apps/cilium) adopts it afterward and owns
# upgrades. Re-render with scripts/render-cilium-bootstrap.sh.
resource "omni_kubernetes_manifest" "cilium_bootstrap" {
  name    = "cilium-bootstrap"
  cluster = omni_cluster.homelab.name
  mode    = "one-time"

  data = file("${path.module}/manifests/cilium-bootstrap.yaml")
}

resource "omni_machine_extensions" "all" {
  cluster = omni_cluster.homelab.name

  extensions = [
    "siderolabs/qemu-guest-agent",
    "siderolabs/iscsi-tools",
    "siderolabs/util-linux-tools",
  ]
}
