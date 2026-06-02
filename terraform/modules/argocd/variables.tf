variable "artifacts_dir" {
  description = "Absolute path to the stack artifacts directory."
  type        = string
}
variable "project_name" {
  type = string
}

variable "argocd_reconciliation_timeout" {
  type = string
}

variable "argocd_server_service_type" {
  type = string
}

variable "argocd_exec_timeout" {
  type = string
}

variable "argocd_repo_server_timeout_secs" {
  type = string
}

variable "gitops_root_app_repo_url" {
  type = string
}
variable "gitops_root_app_target_revision" {
  type = string
}
variable "gitops_root_app_path" {
  type = string
}

variable "metallb_addresses_start" {
  type = string
}
variable "metallb_addresses_end" {
  type = string
}

variable "argocd_cmp_image" {
  type = string
}

variable "cert_manager_acme_email" {
  type = string
}

variable "cert_manager_route53_region" {
  type = string
}

variable "cert_manager_route53_hosted_zone_id" {
  type = string
}

variable "base_domain" {
  type = string
}

variable "cert_manager_version" {
  type = string
}

variable "external_dns_version" {
  type = string
}

variable "external_dns_txt_owner_id" {
  type = string
}

variable "istio_main_version" {
  type = string
}

variable "gateway_api_version" {
  type = string
}

variable "kiali_version" {
  type = string
}

variable "kyverno_version" {
  type = string
}

variable "metallb_version" {
  type = string
}

variable "openebs_version" {
  type = string
}

variable "reflector_version" {
  type = string
}

variable "percona_version" {
  type = string
}

variable "garage_version" {
  type = string
}

variable "kyverno_admission_controller_replicas" {
  type = string
}

variable "kyverno_background_controller_replicas" {
  type = string
}

variable "kyverno_cleanup_controller_replicas" {
  type = string
}

variable "kyverno_reports_controller_replicas" {
  type = string
}

variable "reflector_min_replicas" {
  type = string
}

variable "reflector_max_replicas" {
  type = string
}

variable "stateful_operator_replicas" {
  type = string
}

variable "garage_replication_factor" {
  type = string
}

variable "garage_replicas" {
  type = string
}

variable "istiod_replicas" {
  type = string
}

variable "openebs_localpv_replicas" {
  type = string
}

variable "public_gateway_replicas" {
  type = string
}

variable "public_gateway_min_replicas" {
  type = string
}

variable "public_gateway_max_replicas" {
  type = string
}

variable "cert_manager_replicas" {
  type = string
}

variable "cert_manager_webhook_replicas" {
  type = string
}

variable "cert_manager_cainjector_replicas" {
  type = string
}

variable "kiali_replicas" {
  type = string
}

variable "stateful_resources_pxc_replicas" {
  type = string
}

variable "stateful_resources_haproxy_replicas" {
  type = string
}

variable "grafana_operator_replicas" {
  type = string
}
variable "opentelemetry_operator_replicas" {
  type = string
}

variable "grafana_replicas" {
  type = string
}

variable "otel_gateway_replicas" {
  type = string
}

variable "prometheus_replicas" {
  type = string
}

variable "prometheus_alertmanager_replicas" {
  type = string
}

variable "kube_state_metrics_replicas" {
  type = string
}

variable "loki_backend_replicas" {
  type = string
}

variable "loki_chunks_cache_replicas" {
  type = string
}

variable "loki_gateway_replicas" {
  type = string
}

variable "loki_read_replicas" {
  type = string
}

variable "loki_results_cache_replicas" {
  type = string
}

variable "loki_write_replicas" {
  type = string
}

variable "loki_single_binary_replicas" {
  type = string
}

variable "mimir_alertmanager_replicas" {
  type = string
}

variable "mimir_chunks_cache_replicas" {
  type = string
}

variable "mimir_compactor_replicas" {
  type = string
}

variable "mimir_distributor_replicas" {
  type = string
}

variable "mimir_gateway_replicas" {
  type = string
}

variable "mimir_index_cache_replicas" {
  type = string
}

variable "mimir_ingester_replicas" {
  type = string
}

variable "mimir_metadata_cache_replicas" {
  type = string
}

variable "mimir_overrides_exporter_replicas" {
  type = string
}

variable "mimir_querier_replicas" {
  type = string
}

variable "mimir_query_frontend_replicas" {
  type = string
}

variable "mimir_query_scheduler_replicas" {
  type = string
}

variable "mimir_results_cache_replicas" {
  type = string
}

variable "mimir_ruler_replicas" {
  type = string
}

variable "mimir_store_gateway_replicas" {
  type = string
}

variable "tempo_compactor_replicas" {
  type = string
}

variable "tempo_distributor_replicas" {
  type = string
}

variable "tempo_gateway_replicas" {
  type = string
}

variable "tempo_ingester_replicas" {
  type = string
}

variable "tempo_memcached_replicas" {
  type = string
}

variable "tempo_querier_replicas" {
  type = string
}

variable "tempo_query_frontend_replicas" {
  type = string
}



variable "resource_env" {
  type = map(string)
}

variable "mimir_version" {
  type = string
}
variable "loki_version" {
  type = string
}
variable "tempo_version" {
  type = string
}
variable "prometheus_operator_crds_version" {
  type = string
}

variable "prometheus_operator_version" {
  type = string
}
variable "grafana_operator_version" {
  type = string
}
variable "opentelemetry_operator_version" {
  type = string
}
