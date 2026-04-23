cluster:
  name: ${project_name}
  endpoint: ${cluster_endpoint}
  kubeconfig:
    local_path: ${kubeconfig_local_path}
  ssh_private_key:
    local_path: ${ssh_private_key_path}

tooling:
  kubectl_version: ${kubectl_version}
  helm_version: ${helm_version}

artifacts:
  argocd_values_local_path: ${argocd_values_local_path}
  gitops_root_app_manifest_local_path: ${gitops_root_app_manifest_path}
