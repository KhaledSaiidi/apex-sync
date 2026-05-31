locals {
  argocd_values_artifact_path   = abspath("${var.artifacts_dir}/${var.project_name}-argocd-values.yaml")
  argocd_root_app_artifact_path = abspath("${var.artifacts_dir}/${var.project_name}-argocd-root-app.yaml")
}


resource "local_file" "argocd_values" {
  filename        = local.argocd_values_artifact_path
  file_permission = "0644"
  content = templatefile("${path.module}/templates/argocd_values.tpl", {
    argocd_namespace                = "argocd"
    argocd_server_service_type      = var.argocd_server_service_type
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
    argocd_namespace                       = "argocd"
    gitops_root_app_name                   = "app-of-apps"
    gitops_root_app_project                = "default"
    gitops_root_app_repo_url               = var.gitops_root_app_repo_url
    gitops_root_app_target_revision        = var.gitops_root_app_target_revision
    gitops_root_app_path                   = var.gitops_root_app_path
    gitops_root_app_destination_server     = "https://kubernetes.default.svc"
    gitops_root_app_destination_namespace  = "argocd"
    metallb_addresses_start                = var.metallb_addresses_start
    metallb_addresses_end                  = var.metallb_addresses_end
    cert_manager_acme_email                = var.cert_manager_acme_email
    cert_manager_route53_region            = var.cert_manager_route53_region
    cert_manager_route53_hosted_zone_id    = var.cert_manager_route53_hosted_zone_id
    base_domain                            = var.base_domain
    cert_manager_version                   = var.cert_manager_version
    external_dns_version                   = var.external_dns_version
    external_dns_txt_owner_id              = var.external_dns_txt_owner_id
    istio_main_version                     = var.istio_main_version
    gateway_api_version                    = var.gateway_api_version
    kiali_version                          = var.kiali_version
    kyverno_version                        = var.kyverno_version
    metallb_version                        = var.metallb_version
    openebs_version                        = var.openebs_version
    reflector_version                      = var.reflector_version
    percona_version                        = var.percona_version
    garage_version                         = var.garage_version
    kyverno_admission_controller_replicas  = var.kyverno_admission_controller_replicas
    kyverno_background_controller_replicas = var.kyverno_background_controller_replicas
    kyverno_cleanup_controller_replicas    = var.kyverno_cleanup_controller_replicas
    kyverno_reports_controller_replicas    = var.kyverno_reports_controller_replicas
    reflector_min_replicas                 = var.reflector_min_replicas
    reflector_max_replicas                 = var.reflector_max_replicas
    stateful_operator_replicas             = var.stateful_operator_replicas
    garage_replication_factor              = var.garage_replication_factor
    garage_replicas                        = var.garage_replicas
    istiod_replicas                        = var.istiod_replicas
    openebs_localpv_replicas               = var.openebs_localpv_replicas
    public_gateway_replicas                = var.public_gateway_replicas
    public_gateway_min_replicas            = var.public_gateway_min_replicas
    public_gateway_max_replicas            = var.public_gateway_max_replicas
    cert_manager_replicas                  = var.cert_manager_replicas
    cert_manager_webhook_replicas          = var.cert_manager_webhook_replicas
    cert_manager_cainjector_replicas       = var.cert_manager_cainjector_replicas
    kiali_replicas                         = var.kiali_replicas
    stateful_resources_pxc_replicas        = var.stateful_resources_pxc_replicas
    stateful_resources_haproxy_replicas    = var.stateful_resources_haproxy_replicas
  })
}
