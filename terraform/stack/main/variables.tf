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
  default = "HEAD"
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