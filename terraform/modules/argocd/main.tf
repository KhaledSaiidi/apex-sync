locals {
  argocd_values_artifact_path   = abspath("${var.artifacts_dir}/${var.project_name}-argocd-values.yaml")
  argocd_root_app_artifact_path = abspath("${var.artifacts_dir}/${var.project_name}-argocd-root-app.yaml")
}


resource "local_file" "argocd_values" {
  filename        = local.argocd_values_artifact_path
  file_permission = "0644"
  content = templatefile("${path.module}/templates/argocd_values.tpl", {
    argocd_namespace                = "argocd"
    argocd_server_service_type      = "LoadBalancer"
    argocd_reconciliation_timeout   = var.argocd_reconciliation_timeout
    argocd_exec_timeout             = var.argocd_exec_timeout
    argocd_repo_server_timeout_secs = var.argocd_repo_server_timeout_secs
    argocd_cmp_image                = var.argocd_cmp_image
  })

}

resource "local_file" "argocd_root_app" {
  filename        = local.argocd_root_app_artifact_path
  file_permission = "0644"
  content = templatefile("${path.module}/templates/argocd_root_app.tpl", {
    argocd_namespace                      = "argocd"
    gitops_root_app_name                  = "app-of-apps"
    gitops_root_app_project               = "default"
    gitops_root_app_repo_url              = var.gitops_root_app_repo_url
    gitops_root_app_target_revision       = var.gitops_root_app_target_revision
    gitops_root_app_path                  = var.gitops_root_app_path
    gitops_root_app_destination_server    = "https://kubernetes.default.svc"
    gitops_root_app_destination_namespace = "argocd"
    metallb_addresses_start               = var.metallb_addresses_start
    metallb_addresses_end                 = var.metallb_addresses_end
    cert_manager_acme_email               = var.cert_manager_acme_email
    cert_manager_route53_region           = var.cert_manager_route53_region
    cert_manager_route53_hosted_zone_id   = var.cert_manager_route53_hosted_zone_id
    base_domain                           = var.base_domain
  })
}
