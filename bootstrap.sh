#!/usr/bin/env bash

set -euo pipefail

LOCKFILE="/tmp/kube-signal-terraform.lock"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform/stack/main"
LOG_DIR="${TMPDIR:-/tmp}/kube-signal"
LOG_TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
LOG_FILE="$LOG_DIR/terraform-apply-$LOG_TIMESTAMP.log"

cleanup() {
    echo "Cleaning up lockfile"
    rm -f "$LOCKFILE"
}

trap cleanup EXIT

if ! command -v terraform >/dev/null 2>&1; then
    echo "terraform is not installed or not in PATH."
    exit 1
fi

if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo "Terraform directory not found: $TERRAFORM_DIR"
    exit 1
fi

if ! (set -o noclobber; echo "$$" >"$LOCKFILE") 2>/dev/null; then
    echo "Another terraform operation is already running."
    exit 1
fi

source .env.bootstrap

mkdir -p "$LOG_DIR"

echo "Running terraform apply in $TERRAFORM_DIR"
echo "Logging to $LOG_FILE"

cd "$TERRAFORM_DIR"
terraform init 2>&1 | tee "$LOG_FILE"
terraform apply --auto-approve 2>&1 | tee -a "$LOG_FILE"
