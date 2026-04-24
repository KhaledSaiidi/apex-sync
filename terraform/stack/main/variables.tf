variable "project_name" {
  type    = string
  default = "platform"
}

variable "remote_deployment" {
  type    = bool
  default = false
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
variable "argocd_plugin_version" {
  type    = string
  default = "0.18.0"
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
  default = "gitops/argo-apps/overlays/default/root"
}

variable "kubeconfig_path" {
  type    = string
  default = "../../../kind-kubeconfig.yaml"
}

variable "cluster_endpoint" {
  type    = string
  default = ""
}
