locals {
    artifacts_dir = "${path.root}/artifacts"
}
resource "null_resource" "artifacts_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.artifacts_dir}"
  }
}

module "argocd" {
  source = "../../modules/argocd"

  artifacts_dir                 = local.artifacts_dir
  project_name                  = var.project_name
  argocd_reconciliation_timeout = var.argocd_reconciliation_timeout
  argocd_exec_timeout           = var.argocd_exec_timeout
  argocd_repo_server_timeout_secs = var.argocd_repo_server_timeout_secs

  depends_on = [
    null_resource.artifacts_dir
  ]
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.root}/artifacts/${var.project_name}-inventory.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.tpl", {
    bastion_public_ip          = module.nodegroup.bastion_public_ip
    ansible_user               = "ec2-user"
    ssh_private_key_path       = module.nodegroup.ssh_private_key_path
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
    # Identity / meta
    project_name = var.project_name
  })

  depends_on = [
    null_resource.artifacts_dir,
    module.argocd
  ]
}
