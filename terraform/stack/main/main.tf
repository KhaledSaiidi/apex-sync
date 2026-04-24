locals {
  artifacts_dir   = "${path.root}/artifacts"
  repo_root       = abspath("${path.root}/../../../")
  kubeconfig_path = startswith(pathexpand(var.kubeconfig_path), "/") ? pathexpand(var.kubeconfig_path) : abspath("${path.root}/${pathexpand(var.kubeconfig_path)}")
}
resource "null_resource" "artifacts_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.artifacts_dir}"
  }
}

module "argocd" {
  source = "../../modules/argocd"

  artifacts_dir                   = local.artifacts_dir
  project_name                    = var.project_name
  argocd_reconciliation_timeout   = var.argocd_reconciliation_timeout
  argocd_exec_timeout             = var.argocd_exec_timeout
  argocd_repo_server_timeout_secs = var.argocd_repo_server_timeout_secs
  argocd_plugin_version           = var.argocd_plugin_version
  gitops_root_app_repo_url        = var.gitops_root_app_repo_url
  gitops_root_app_target_revision = var.gitops_root_app_target_revision
  gitops_root_app_path            = var.gitops_root_app_path

  depends_on = [
    null_resource.artifacts_dir
  ]
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.root}/artifacts/${var.project_name}-inventory.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.tpl", {
    argocd_values_local_path   = module.argocd.argocd_values_path
    gitops_root_app_local_path = module.argocd.argocd_root_app_path
  })

  depends_on = [
    null_resource.artifacts_dir,
    module.argocd
  ]
}

resource "local_file" "ansible_vars" {
  filename        = "${path.root}/artifacts/${var.project_name}-ansible-vars.yaml"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/ansible_vars.tpl", {
    project_name                  = var.project_name
    kubeconfig_local_path         = local.kubeconfig_path
    cluster_endpoint              = var.cluster_endpoint
    argocd_values_local_path      = module.argocd.argocd_values_path
    gitops_root_app_manifest_path = module.argocd.argocd_root_app_path
  })

  depends_on = [
    null_resource.artifacts_dir,
    module.argocd
  ]
}

module "bootstrap_ansible" {
  source = "../../modules/bootstrap_ansible"

  inventory_file_path = local_file.ansible_inventory.filename
  inventory_content   = local_file.ansible_inventory.content
  requirements_path   = "${local.repo_root}/ansible/requirements.yml"
  vars_file_path      = local_file.ansible_vars.filename
  vars_content        = local_file.ansible_vars.content
  playbook_path       = "${local.repo_root}/ansible/playbooks/bootstrap.yml"
  working_directory   = local.repo_root

  depends_on = [
    local_file.ansible_inventory,
    local_file.ansible_vars
  ]
}
