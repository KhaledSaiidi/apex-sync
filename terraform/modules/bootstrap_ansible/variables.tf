variable "playbook_path" {
  type = string
}

variable "requirements_path" {
  type = string
}

variable "bootstrap_sources_sha256" {
  type = string
}

variable "bootstrap_artifacts_sha256" {
  type = string
}

variable "working_directory" {
  type = string
}

variable "artifacts_dir" {
  type = string
}
variable "project_name" {
  type = string
}

variable "ansible_python_interpreter" {
  type = string
}

variable "kubeconfig_path" {
  type = string
}
variable "gitops_root_app_repo_url" {
  type = string
}
variable "github_app_id" {
  type = string
}
variable "github_app_installation_id" {
  type = string
}
variable "github_app_private_key" {
  type      = string
  sensitive = true
}
variable "aws_access_key_id" {
  type = string
}
variable "aws_secret_access_key" {
  type = string
}

variable "argocd_values_path" {
  type = string
}
variable "argocd_root_app_path" {
  type = string
}

variable "argocd_chart_version" {
  type = string
}

variable "cilium_chart_version" {
  type = string
}

variable "cilium_image_pull_policy" {
  type = string
}

variable "cilium_ipam_mode" {
  type = string
}

variable "cilium_k8s_service_host" {
  type = string
}

variable "cilium_k8s_service_port" {
  type = string
}

variable "cilium_kube_proxy_replacement" {
  type = string
}

variable "cilium_socket_lb_host_namespace_only" {
  type = string
}

variable "cilium_cni_exclusive" {
  type = string
}

variable "cilium_hubble_enabled" {
  type = string
}

variable "cilium_hubble_relay_enabled" {
  type = string
}

variable "cilium_hubble_ui_enabled" {
  type = string
}
