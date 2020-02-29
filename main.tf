provider "digitalocean" {
  version = "~> 1.14"
}

data "digitalocean_kubernetes_versions" "latest" {}

resource "digitalocean_kubernetes_cluster" "multijuicer" {
  name   = "multi-juicer"
  region = "fra1"

  # Use latest digitalocean k8s version
  version = data.digitalocean_kubernetes_versions.latest.latest_version

  node_pool {
    name       = "primary-pool"
    size       = "s-2vcpu-4gb"
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 3
  }
}

provider "helm" {
  version = "~> 1.0"
  kubernetes {
    load_config_file = false
    host             = digitalocean_kubernetes_cluster.multijuicer.endpoint
    token            = digitalocean_kubernetes_cluster.multijuicer.kube_config[0].token
    cluster_ca_certificate = base64decode(
      digitalocean_kubernetes_cluster.multijuicer.kube_config[0].cluster_ca_certificate
    )
  }
}

provider "kubernetes" {
  load_config_file = false
  host             = digitalocean_kubernetes_cluster.multijuicer.endpoint
  token            = digitalocean_kubernetes_cluster.multijuicer.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.multijuicer.kube_config[0].cluster_ca_certificate
  )
}

# data "helm_repository" "multijuicer" {
#   name = "multi-juicer"
#   url  = "https://iteratec.github.io/multi-juicer/"
# }

data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

data "helm_repository" "loki" {
  name = "loki"
  url  = "https://grafana.github.io/loki/charts"
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}


resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = "monitoring"
  chart      = "prometheus-operator"
  repository = data.helm_repository.stable.metadata[0].name
  version    = "8.9.3"

  set {
    name  = "grafana.adminPassword"
    value = "foobar"
  }
  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }
  # set {
  #   name  = "grafana.service.loadBalancerIP"
  #   value = "LoadBalancer"
  # }

  values = [
    file("./prometheus-operator-config.yaml")
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

resource "helm_release" "loki" {
  name       = "loki"
  namespace  = "monitoring"
  chart      = "loki"
  repository = data.helm_repository.loki.metadata[0].name
  version    = "0.25.1"

  set {
    name  = "serviceMonitor.enabled"
    value = "true"
  }

  depends_on = [helm_release.prometheus]
}

resource "helm_release" "promtail" {
  name       = "promtail"
  namespace  = "monitoring"
  chart      = "promtail"
  repository = data.helm_repository.loki.metadata[0].name
  version    = "0.19.2"

  set {
    name  = "loki.serviceName"
    value = "loki"
  }
  set {
    name  = "serviceMonitor.enabled"
    value = "true"
  }

  depends_on = [helm_release.loki]
}

resource "helm_release" "multijuicer" {
  name = "multi-juicer"

  chart = "../multi-juicer/helm/multi-juicer/"

  # repository = data.helm_repository.multijuicer.metadata[0].name
  # chart      = "multi-juicer"
  # version    = "2.1.3"

  depends_on = [helm_release.prometheus]

  # tmp section to use the container images of the next release
  set {
    name  = "balancer.tag"
    value = "next"
  }
  set {
    name  = "balancer.tag"
    value = "next"
  }
  set {
    name  = "juiceShop.tag"
    value = "snapshot"
  }
  set {
    name  = "juiceShopCleanup.tag"
    value = "next"
  }
  set {
    name  = "progressWatchdog.tag"
    value = "next"
  }



  set {
    name  = "balancer.metrics.enabled"
    value = "true"
  }
  set {
    name  = "balancer.metrics.dashboards.enabled"
    value = "true"
  }
  set {
    name  = "balancer.metrics.serviceMonitor.enabled"
    value = "true"
  }
}
