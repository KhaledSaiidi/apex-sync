apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${gitops_root_app_name}
  namespace: ${argocd_namespace}
  labels:
    app.kubernetes.io/managed-by: terraform
    app.kubernetes.io/part-of: gitops-bootstrap
spec:
  project: ${gitops_root_app_project}
  source:
    repoURL: ${gitops_root_app_repo_url}
    targetRevision: ${gitops_root_app_target_revision}
    path: ${gitops_root_app_path}
    plugin:
      name: envsubstappofapp
      env:
        - name: metallb_config_mode
          value: "${metallb_mode}"
        - name: metallb_config_addresses_start
          value: "${metallb_addresses_start}"
        - name: metallb_config_addresses_end
          value: "${metallb_addresses_end}"
  destination:
    server: ${gitops_root_app_destination_server}
    namespace: ${gitops_root_app_destination_namespace}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
