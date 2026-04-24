variable "inventory_file_path" {
  type = string
}

variable "inventory_content" {
  type = string
}

variable "vars_file_path" {
  type = string
}

variable "vars_content" {
  type = string
}

variable "playbook_path" {
  type = string
}

variable "requirements_path" {
  type = string
}

variable "bootstrap_sources_sha256" {
  type = string
}

variable "bootstrap_artifacts_sha256" {
  type = string
}

variable "working_directory" {
  type = string
}
