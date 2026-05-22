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
  gitops_root_app_repo_url        = var.gitops_root_app_repo_url
  gitops_root_app_target_revision = var.gitops_root_app_target_revision
  gitops_root_app_path            = var.gitops_root_app_path
  metallb_addresses_start         = var.metallb_addresses_start
  metallb_addresses_end           = var.metallb_addresses_end
  argocd_cmp_image                = var.argocd_cmp_image

  depends_on = [
    null_resource.artifacts_dir
  ]
}



module "bootstrap_ansible" {
  source                     = "../../modules/bootstrap_ansible"
  artifacts_dir              = local.artifacts_dir
  argocd_root_app_path       = module.argocd.argocd_root_app_path
  argocd_values_path         = module.argocd.argocd_values_path
  kubeconfig_path            = local.kubeconfig_path
  ansible_python_interpreter = var.ansible_python_interpreter
  project_name               = var.project_name
  cluster_endpoint           = var.cluster_endpoint
  gitops_root_app_repo_url   = var.gitops_root_app_repo_url
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key
  aws_access_key_id          = var.aws_access_key_id
  aws_secret_access_key      = var.aws_secret_access_key
  argocd_chart_version       = var.argocd_chart_version
  requirements_path          = "${local.repo_root}/ansible/requirements.yml"
  playbook_path              = "${local.repo_root}/ansible/playbooks/bootstrap.yml"
  bootstrap_sources_sha256   = local.bootstrap_sources_sha256
  bootstrap_artifacts_sha256 = local.bootstrap_artifacts_sha256
  working_directory          = local.repo_root
}
