output "argocd_values_path" {
  value = local_file.argocd_values.filename
}

output "argocd_root_app_path" {
  value = local_file.argocd_root_app.filename
}
