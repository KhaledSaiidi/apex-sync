output "argocd_values_path" {
  value = local_file.argocd_values.filename
}

output "argocd_values_sha256" {
  value = sha256(local_file.argocd_values.content)
}

output "argocd_root_app_path" {
  value = local_file.argocd_root_app.filename
}

output "argocd_root_app_sha256" {
  value = sha256(local_file.argocd_root_app.content)
}
