variable "artifacts_dir" {
  description = "Absolute path to the stack artifacts directory."
  type        = string
}
variable "project_name" {
  type    = string
  default = "platform"
}

variable "remote_deployment" {
  type    = bool
  default = false
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
  default = "v0.18.0"
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

variable "ansible_user" {
  description = "SSH user for bastion mode and local user name for local mode."
  type        = string
}

variable "kubeconfig_path" {
  type    = string
  default = "../../../kind-kubeconfig.yaml"
}

variable "cluster_endpoint" {
  type    = string
  default = ""
}

variable "kubectl_version" {
  type    = string
  default = "v1.34.1"
}

variable "helm_version" {
  type    = string
  default = "v3.19.0"
}
