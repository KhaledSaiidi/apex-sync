variable "artifacts_dir" {
  description = "Absolute path to the stack artifacts directory."
  type        = string
}
variable "project_name" {
  type    = string
  default = "platform"
}

variable "argocd_reconciliation_timeout" {
  type = string
}

variable "argocd_exec_timeout" {
  type = string
}

variable "argocd_repo_server_timeout_secs" {
  type = string
}

variable "gitops_root_app_repo_url" {
  type    = string
  default = "https://github.com/KhaledSaiidi/kube-signal.git"
}
variable "gitops_root_app_target_revision" {
  type    = string
  default = "HEAD"
}
variable "gitops_root_app_path" {
  type    = string
  default = "gitops/argo-apps"
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
