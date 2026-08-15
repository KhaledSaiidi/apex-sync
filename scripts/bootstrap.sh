#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

CONFIG_DIR="$REPO_ROOT/override-config"
ENV_FILE="$REPO_ROOT/.env.bootstrap"
LOCKFILE="/tmp/apex-sync-terraform.lock"
TERRAFORM_DIR="$REPO_ROOT/terraform/stack/main"

LOG_DIR="${TMPDIR:-/tmp}/apex-sync"
LOG_TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
LOG_FILE="$LOG_DIR/terraform-apply-$LOG_TIMESTAMP.log"

cleanup() {
  if [[ -f "$LOCKFILE" ]] && [[ "$(cat "$LOCKFILE")" == "$$" ]]; then
    echo "Cleaning up lockfile"
    rm -f "$LOCKFILE"
  fi
}

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is not installed or not in PATH."
  exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is not installed or not in PATH."
  exit 1
fi

if [[ ! -d "$CONFIG_DIR" ]]; then
  echo "Config directory not found: $CONFIG_DIR"
  exit 1
fi

if [[ ! -d "$TERRAFORM_DIR" ]]; then
  echo "Terraform directory not found: $TERRAFORM_DIR"
  exit 1
fi

if [[ -f "$ENV_FILE" ]] && [[ "${APEX_SYNC_SKIP_ENV_FILE:-0}" != "1" ]]; then
  echo "Loading bootstrap environment from $ENV_FILE"
  # shellcheck source=/dev/null
  source "$ENV_FILE"
elif [[ "${APEX_SYNC_SKIP_ENV_FILE:-0}" == "1" ]]; then
  echo "Skipping local bootstrap environment file for CI execution."
else
  echo "Bootstrap environment file not found; using the current process environment."
fi

# The S3 backend consumes the standard AWS variables, while the existing
# Terraform/Ansible bootstrap consumes their TF_VAR_* equivalents. Populate
# whichever form is missing so local and CI execution behave consistently.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]] && [[ -n "${TF_VAR_aws_access_key_id:-}" ]]; then
  export AWS_ACCESS_KEY_ID="$TF_VAR_aws_access_key_id"
fi
if [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]] && [[ -n "${TF_VAR_aws_secret_access_key:-}" ]]; then
  export AWS_SECRET_ACCESS_KEY="$TF_VAR_aws_secret_access_key"
fi
if [[ -z "${TF_VAR_aws_access_key_id:-}" ]] && [[ -n "${AWS_ACCESS_KEY_ID:-}" ]]; then
  export TF_VAR_aws_access_key_id="$AWS_ACCESS_KEY_ID"
fi
if [[ -z "${TF_VAR_aws_secret_access_key:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  export TF_VAR_aws_secret_access_key="$AWS_SECRET_ACCESS_KEY"
fi

required_vars=(
  TF_VAR_github_app_id
  TF_VAR_github_app_installation_id
  TF_VAR_github_app_private_key
  TF_VAR_aws_access_key_id
  TF_VAR_aws_secret_access_key
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
)

missing_vars=()
for required_var in "${required_vars[@]}"; do
  if [[ -z "${!required_var:-}" ]]; then
    missing_vars+=("$required_var")
  fi
done

if [[ "${#missing_vars[@]}" -gt 0 ]]; then
  echo "Missing required bootstrap environment variables:"
  printf '  - %s\n' "${missing_vars[@]}"
  exit 1
fi

if ! (set -o noclobber; echo "$$" > "$LOCKFILE") 2>/dev/null; then
  echo "Another terraform operation is already running."
  exit 1
fi

trap cleanup EXIT

shopt -s nullglob
CONFIG_FILES=("$CONFIG_DIR"/*.yaml "$CONFIG_DIR"/*.yml)
shopt -u nullglob

if [[ "${#CONFIG_FILES[@]}" -eq 0 ]]; then
  echo "No config YAML files found in: $CONFIG_DIR"
  exit 1
fi

for config_file in "${CONFIG_FILES[@]}"; do
  while IFS='=' read -r key value; do
    export "TF_VAR_${key}=${value}"
  done < <(
    yq -r '
      to_entries[]
      | select(.value != null and (.value | type != "object") and (.value | type != "array"))
      | "\(.key)=\(.value)"
    ' "$config_file"
  )
done

mkdir -p "$LOG_DIR"

echo "Running terraform apply in $TERRAFORM_DIR"
echo "Logging to $LOG_FILE"

cd "$TERRAFORM_DIR"

terraform init -input=false 2>&1 | tee "$LOG_FILE"
terraform apply -input=false -auto-approve -lock-timeout=10m 2>&1 | tee -a "$LOG_FILE"
