# Hetzner provider uses your token
provider "hcloud" {
  token = var.hcloud_token
}

# Use the official hcloud-k8s module (Registry)
module "kubernetes" {
  source  = "hcloud-k8s/kubernetes/hcloud"
  version = "3.12.0"

  # Required
  cluster_name = var.cluster_name
  hcloud_token = var.hcloud_token

  # Optional but very helpful: write configs to files
  cluster_kubeconfig_path  = "kubeconfig"
  cluster_talosconfig_path = "talosconfig"

  # --- Control plane nodepool: 3 CPX21 in hel1 (Helsinki)
  control_plane_nodepools = [
    {
      name     = "cp"
      type     = "cpx22"
      location = "hel1"
      count    = 3
    }
  ]

  # --- Worker nodepool: 1 CPX21 in hel1
  worker_nodepools = [
    {
      name     = "worker"
      type     = "cpx22"
      location = "hel1"
      count    = 1
    }
  ]
}

