provider "digitalocean" {
  version = "~> 1.14"
}

data "digitalocean_kubernetes_versions" "latest" {}

resource "digitalocean_kubernetes_cluster" "multijuicer" {
  name    = "multi-juicer"
  region  = "fra1"

  # Use latest digitalocean k8s version
  version = data.digitalocean_kubernetes_versions.latest.latest_version

  node_pool {
    name       = "primary-pool"
    size       = "s-2vcpu-4gb"
    auto_scale = true
    min_nodes = 1
    max_nodes = 3
  }
}

provider "helm" {
  version = "~> 1.0"
  kubernetes {
    host  = digitalocean_kubernetes_cluster.multijuicer.endpoint
    token = digitalocean_kubernetes_cluster.multijuicer.kube_config[0].token
    cluster_ca_certificate = base64decode(
        digitalocean_kubernetes_cluster.multijuicer.kube_config[0].cluster_ca_certificate
    )
  }
}

data "helm_repository" "multijuicer" {
  name = "multi-juicer"
  url  = "https://iteratec.github.io/multi-juicer/"
}

resource "helm_release" "multijuicer" {
  name       = "multi-juicer"
  repository = data.helm_repository.multijuicer.metadata[0].name
  chart      = "multi-juicer"
  version    = "2.1.3"
}
