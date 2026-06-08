cluster:
  kubeconfig:
    local_path: "${kubeconfig_local_path}"

artifacts:
  argocd_values_local_path: "${argocd_values_local_path}"
  gitops_root_app_manifest_local_path: "${gitops_root_app_manifest_path}"

github:
  gitops_root_app_repo_url: "${gitops_root_app_repo_url}"
  github_app_id: "${github_app_id}"
  github_app_installation_id: "${github_app_installation_id}"
  github_app_private_key: |-
    ${indent(4, github_app_private_key)}

aws:
  access_key_id: "${aws_access_key_id}"
  secret_access_key: "${aws_secret_access_key}"

argocd:
  argocd_chart_version: "${argocd_chart_version}"

cilium:
  cilium_chart_version: "${cilium_chart_version}"
  cilium_image_pull_policy: "${cilium_image_pull_policy}"
  cilium_ipam_mode: "${cilium_ipam_mode}"
  cilium_k8s_service_host: "${cilium_k8s_service_host}"
  cilium_k8s_service_port: "${cilium_k8s_service_port}"
  cilium_kube_proxy_replacement: "${cilium_kube_proxy_replacement}"
  cilium_socket_lb_host_namespace_only: "${cilium_socket_lb_host_namespace_only}"
  cilium_cni_exclusive: "${cilium_cni_exclusive}"
  cilium_hubble_enabled: "${cilium_hubble_enabled}"
  cilium_hubble_relay_enabled: "${cilium_hubble_relay_enabled}"
  cilium_hubble_ui_enabled: "${cilium_hubble_ui_enabled}"
