variable "hcloud_token" {
  type        = string
  description = "Hetzner Cloud API token"
  sensitive   = true
}

variable "cluster_name" {
  type        = string
  description = "Cluster name"
  default     = "talos-hel1-sfs"
}
