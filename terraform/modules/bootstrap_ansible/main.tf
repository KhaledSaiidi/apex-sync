locals {
  ansible_tmp_dir         = "${var.working_directory}/.ansible/tmp"
  ansible_collections_dir = "${var.working_directory}/.ansible/collections"
  ansible_roles_dir       = "${var.working_directory}/ansible/roles"
}

resource "null_resource" "requirements" {
  triggers = {
    inventory_sha256    = sha256(var.inventory_content)
    vars_sha256         = sha256(var.vars_content)
    playbook_sha256     = filesha256(var.playbook_path)
    requirements_sha256 = filesha256(var.requirements_path)
  }

  provisioner "local-exec" {
    command = "mkdir -p '${local.ansible_tmp_dir}' '${local.ansible_collections_dir}' && ansible-galaxy collection install -r '${var.requirements_path}' -p '${local.ansible_collections_dir}'"
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
    inventory_sha256           = sha256(var.inventory_content)
    vars_sha256                = sha256(var.vars_content)
    playbook_sha256            = filesha256(var.playbook_path)
    requirements_sha256        = filesha256(var.requirements_path)
    bootstrap_sources_sha256   = var.bootstrap_sources_sha256
    bootstrap_artifacts_sha256 = var.bootstrap_artifacts_sha256
  }

  provisioner "local-exec" {
    command = "mkdir -p '${local.ansible_tmp_dir}' '${local.ansible_collections_dir}' && ansible-playbook -i '${var.inventory_file_path}' '${var.playbook_path}' --extra-vars '@${var.vars_file_path}'"
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
