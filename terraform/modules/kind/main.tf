resource "kind_cluster" "default" {
  name            = var.cluster_name
  wait_for_ready  = false
  kubeconfig_path = var.kubeconfig_path

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    networking {
      disable_default_cni = true
      kube_proxy_mode     = "none"
    }

    node { role = "control-plane" }
    node { role = "worker" }
    node { role = "worker" }
    node { role = "worker" }
  }
}