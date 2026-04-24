resource "null_resource" "requirements" {
  triggers = {
    inventory_sha256 = sha256(var.inventory_content)
    vars_sha256      = sha256(var.vars_content)
    playbook_sha256  = filesha256(var.playbook_path)
  }

  provisioner "local-exec" {
    command = "ansible-galaxy collection install -r ${var.requirements_path}"
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
    working_dir = var.working_directory
  }
}

resource "null_resource" "bootstrap" {
  triggers = {
    inventory_sha256 = sha256(var.inventory_content)
    vars_sha256      = sha256(var.vars_content)
    playbook_sha256  = filesha256(var.playbook_path)
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ${var.inventory_file_path} ${var.playbook_path} --extra-vars @${var.vars_file_path}"
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
    working_dir = var.working_directory
  }
}
