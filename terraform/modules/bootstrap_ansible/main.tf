locals {
  ansible_tmp_dir         = "${var.working_directory}/.ansible/tmp"
  ansible_collections_dir = "${var.working_directory}/.ansible/collections"
  ansible_roles_dir       = "${var.working_directory}/ansible/roles"
}

resource "local_file" "ansible_inventory" {
  filename        = "${var.artifacts_dir}/${var.project_name}-inventory.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.tpl", {
    ansible_python_interpreter = var.ansible_python_interpreter
    argocd_values_local_path   = var.argocd_values_path
    gitops_root_app_local_path = var.argocd_root_app_path
  })
}

resource "local_file" "ansible_vars" {
  filename        = "${var.artifacts_dir}/${var.project_name}-ansible-vars.yaml"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/ansible_vars.tpl", {
    project_name                  = var.project_name
    kubeconfig_local_path         = var.kubeconfig_path
    cluster_endpoint              = var.cluster_endpoint
    argocd_values_local_path      = var.argocd_values_path
    gitops_root_app_manifest_path = var.argocd_root_app_path
    gitops_root_app_repo_url      = var.gitops_root_app_repo_url
    github_app_id                 = var.github_app_id
    github_app_installation_id    = var.github_app_installation_id
    github_app_private_key        = var.github_app_private_key
    aws_access_key_id             = var.aws_access_key_id
    aws_secret_access_key         = var.aws_secret_access_key
    argocd_chart_version          = var.argocd_chart_version
  })
}
resource "null_resource" "requirements" {
  triggers = {
    inventory_sha256    = sha256(local_file.ansible_inventory.content)
    vars_sha256         = sha256(local_file.ansible_vars.content)
    playbook_sha256     = filesha256(var.playbook_path)
    requirements_sha256 = filesha256(var.requirements_path)
  }

  provisioner "local-exec" {
    command = "mkdir -p '${local.ansible_tmp_dir}' '${local.ansible_collections_dir}' && ansible-galaxy collection install -U -r '${var.requirements_path}' -p '${local.ansible_collections_dir}'"
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
      ANSIBLE_LOCAL_TEMP        = local.ansible_tmp_dir
      ANSIBLE_COLLECTIONS_PATH  = local.ansible_collections_dir
      ANSIBLE_ROLES_PATH        = local.ansible_roles_dir
    }
    working_dir = var.working_directory
  }
}

resource "null_resource" "bootstrap" {
  triggers = {
    inventory_sha256           = sha256(local_file.ansible_inventory.content)
    vars_sha256                = sha256(local_file.ansible_vars.content)
    playbook_sha256            = filesha256(var.playbook_path)
    requirements_sha256        = filesha256(var.requirements_path)
    bootstrap_sources_sha256   = var.bootstrap_sources_sha256
    bootstrap_artifacts_sha256 = var.bootstrap_artifacts_sha256
  }

  provisioner "local-exec" {
    command = "mkdir -p '${local.ansible_tmp_dir}' '${local.ansible_collections_dir}' && ansible-playbook -i '${local_file.ansible_inventory.filename}' '${var.playbook_path}' --extra-vars '@${local_file.ansible_vars.filename}'"
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
      ANSIBLE_LOCAL_TEMP        = local.ansible_tmp_dir
      ANSIBLE_COLLECTIONS_PATH  = local.ansible_collections_dir
      ANSIBLE_ROLES_PATH        = local.ansible_roles_dir
    }
    working_dir = var.working_directory
  }

  depends_on = [
    null_resource.requirements
  ]
}
