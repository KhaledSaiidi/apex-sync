[bastion]
bastion_host ansible_host=${bastion_public_ip} ansible_user=${ansible_user} ansible_ssh_private_key_file=${ssh_private_key_path} ansible_python_interpreter=/usr/bin/python3 argocd_values_local_path=${argocd_values_local_path} gitops_root_app_manifest_local_path=${gitops_root_app_local_path}
