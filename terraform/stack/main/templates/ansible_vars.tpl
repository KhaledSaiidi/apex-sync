cluster:
  name: "${project_name}"
  endpoint: "${cluster_endpoint}"
  kubeconfig:
    local_path: "${kubeconfig_local_path}"

artifacts:
  argocd_values_local_path: "${argocd_values_local_path}"
  gitops_root_app_manifest_local_path: "${gitops_root_app_manifest_path}"
