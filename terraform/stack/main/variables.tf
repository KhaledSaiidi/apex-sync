variable "project_name" {
  type    = string
  default = "platform"
}

variable "argocd_reconciliation_timeout" {
  type    = string
  default = "180s"
}

variable "argocd_exec_timeout" {
  type    = string
  default = "180s"
}

variable "argocd_repo_server_timeout_secs" {
  type    = string
  default = "300"
}

variable "gitops_root_app_repo_url" {
  type    = string
  default = "https://github.com/KhaledSaiidi/kube-signal.git"
}
variable "gitops_root_app_target_revision" {
  type    = string
  default = "test/platform-stateful-resources"
}
variable "gitops_root_app_path" {
  type    = string
  default = "gitops/argo-apps"
}

variable "ansible_python_interpreter" {
  type    = string
  default = "/usr/bin/python3"
}

variable "kubeconfig_path" {
  type    = string
  default = "../../../kind-kubeconfig.yaml"
}


variable "github_app_id" {
  type = string
}

variable "github_app_installation_id" {
  type = string
}

variable "github_app_private_key" {
  type = string
}

variable "aws_access_key_id" {
  type = string
}
variable "aws_secret_access_key" {
  type = string
}

variable "metallb_addresses_start" {
  type    = string
  default = "172.18.255.200"
}

variable "metallb_addresses_end" {
  type    = string
  default = "172.18.255.230"

}

variable "argocd_cmp_image" {
  type    = string
  default = "ghcr.io/khaledsaiidi/kube-signal/argocd-cmp-envsubst:1.2.0"
}

variable "argocd_chart_version" {
  type    = string
  default = "9.5.15"
}

variable "cert_manager_acme_email" {
  type    = string
  default = "khaled.saiidi@outlook.com"
}

variable "cert_manager_route53_region" {
  type    = string
  default = "us-east-1"
}

variable "cert_manager_route53_hosted_zone_id" {
  type    = string
  default = "Z032863786J0OF6PKT1D"
}

variable "base_domain" {
  type    = string
  default = "kube-forge.com"
}

variable "cert_manager_version" {
  type    = string
  default = "v1.20.2"
}

variable "external_dns_version" {
  type    = string
  default = "1.21.1"
}

variable "external_dns_txt_owner_id" {
  type    = string
  default = "kube-signal"
}

variable "istio_main_version" {
  type    = string
  default = "1.29.2"
}

variable "gateway_api_version" {
  type    = string
  default = "v1.5.1"
}

variable "kiali_version" {
  type    = string
  default = "2.26.0"
}

variable "kyverno_version" {
  type    = string
  default = "3.8.0"
}

variable "metallb_version" {
  type    = string
  default = "0.15.3"
}

variable "openebs_version" {
  type    = string
  default = "4.4.0"
}

variable "reflector_version" {
  type    = string
  default = "10.0.45"
}

variable "percona_version" {
  type    = string
  default = "1.19.1"
}

variable "garage_version" {
  type    = string
  default = "2.3.1"
}
