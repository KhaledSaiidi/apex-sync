locals {
  artifacts_dir            = abspath("${path.root}/artifacts")
  repo_root                = abspath("${path.root}/../../../")
  kubeconfig_path          = startswith(pathexpand(var.kubeconfig_path), "/") ? pathexpand(var.kubeconfig_path) : abspath("${path.root}/${pathexpand(var.kubeconfig_path)}")
  bootstrap_sources_files  = sort(concat(["ansible.cfg"], tolist(fileset(local.repo_root, "ansible/**/*.yml")), tolist(fileset(local.repo_root, "ansible/**/*.yaml"))))
  bootstrap_sources_sha256 = sha256(join("", [for file in local.bootstrap_sources_files : filesha256("${local.repo_root}/${file}")]))
  bootstrap_artifacts_sha256 = sha256(join("", [
    module.argocd.argocd_values_sha256,
    module.argocd.argocd_root_app_sha256
  ]))
}
resource "null_resource" "artifacts_dir" {
  provisioner "local-exec" {
    command = "mkdir -p '${local.artifacts_dir}'"
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
  filename        = "${local.artifacts_dir}/${var.project_name}-inventory.ini"
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
  filename        = "${local.artifacts_dir}/${var.project_name}-ansible-vars.yaml"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/ansible_vars.tpl", {
    project_name                  = var.project_name
    kubeconfig_local_path         = local.kubeconfig_path
    cluster_endpoint              = var.cluster_endpoint
    argocd_values_local_path      = module.argocd.argocd_values_path
    gitops_root_app_manifest_path = module.argocd.argocd_root_app_path
    gitops_root_app_repo_url      = var.gitops_root_app_repo_url
    github_app_id                 = var.github_app_id
    github_app_installation_id    = var.github_app_installation_id
    github_app_private_key        = var.github_app_private_key
  })

  depends_on = [
    null_resource.artifacts_dir,
    module.argocd
  ]
}

module "bootstrap_ansible" {
  source = "../../modules/bootstrap_ansible"

  inventory_file_path        = abspath(local_file.ansible_inventory.filename)
  inventory_content          = local_file.ansible_inventory.content
  requirements_path          = "${local.repo_root}/ansible/requirements.yml"
  vars_file_path             = abspath(local_file.ansible_vars.filename)
  vars_content               = local_file.ansible_vars.content
  playbook_path              = "${local.repo_root}/ansible/playbooks/bootstrap.yml"
  bootstrap_sources_sha256   = local.bootstrap_sources_sha256
  bootstrap_artifacts_sha256 = local.bootstrap_artifacts_sha256
  working_directory          = local.repo_root

  depends_on = [
    local_file.ansible_inventory,
    local_file.ansible_vars
  ]
}
