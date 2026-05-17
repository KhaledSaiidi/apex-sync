cluster:
  name: "${project_name}"
  endpoint: "${cluster_endpoint}"
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

