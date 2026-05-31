#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

CONFIG_FILE="$SCRIPT_DIR/custom-config.yaml"
ENV_FILE="$SCRIPT_DIR/.env.bootstrap"
LOCKFILE="/tmp/kube-signal-terraform.lock"
TERRAFORM_DIR="$SCRIPT_DIR/terraform/stack/main"

LOG_DIR="${TMPDIR:-/tmp}/kube-signal"
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

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Custom config file not found: $CONFIG_FILE"
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Bootstrap env file not found: $ENV_FILE"
  exit 1
fi

if [[ ! -d "$TERRAFORM_DIR" ]]; then
  echo "Terraform directory not found: $TERRAFORM_DIR"
  exit 1
fi

if ! (set -o noclobber; echo "$$" > "$LOCKFILE") 2>/dev/null; then
  echo "Another terraform operation is already running."
  exit 1
fi

trap cleanup EXIT

source "$ENV_FILE"

while IFS='=' read -r key value; do
  export "TF_VAR_${key}=${value}"
done < <(
  yq -r '
    to_entries[]
    | select(.value != null)
    | "\(.key)=\(.value)"
  ' "$CONFIG_FILE"
)

mkdir -p "$LOG_DIR"

echo "Running terraform apply in $TERRAFORM_DIR"
echo "Logging to $LOG_FILE"

cd "$TERRAFORM_DIR"

terraform init 2>&1 | tee "$LOG_FILE"
terraform apply --auto-approve 2>&1 | tee -a "$LOG_FILE"
