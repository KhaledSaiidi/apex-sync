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

    node {
      role = "control-plane"

      # HAProxy terminates no TLS for the Kubernetes API. Include its public
      # hostname in the API server certificate so remote kubectl clients can
      # validate the upstream certificate end-to-end.
      kubeadm_config_patches = [
        <<-YAML
        kind: ClusterConfiguration
        apiServer:
          certSANs:
            - ${var.kubernetes_api_dns_name}
        YAML
      ]
    }
    node { role = "worker" }
    node { role = "worker" }
    node { role = "worker" }
  }
}
