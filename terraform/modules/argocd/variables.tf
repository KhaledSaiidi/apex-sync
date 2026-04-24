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
