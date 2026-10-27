#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
EXPECTED_COMMIT="${1:-}"
TERRAFORM_DIR="$REPO_ROOT/terraform/stack/main"

cleanup() {
  unset \
    TF_VAR_github_app_id \
    TF_VAR_github_app_installation_id \
    TF_VAR_github_app_private_key \
    TF_VAR_aws_access_key_id \
    TF_VAR_aws_secret_access_key \
    AWS_ACCESS_KEY_ID \
    AWS_SECRET_ACCESS_KEY
}
trap cleanup EXIT

if [[ ! "$EXPECTED_COMMIT" =~ ^[0-9a-fA-F]{40}$ ]]; then
  echo "Invalid expected commit SHA."
  exit 1
fi

ACTUAL_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
if [[ "$ACTUAL_COMMIT" != "$EXPECTED_COMMIT" ]]; then
  echo "Remote repository is at $ACTUAL_COMMIT, expected $EXPECTED_COMMIT."
  exit 1
fi

read_payload_value() {
  local variable_name="$1"
  local variable_value

  if ! IFS= read -r -d '' variable_value; then
    echo "Failed to read required secret payload for $variable_name."
    exit 1
  fi

  printf -v "$variable_name" '%s' "$variable_value"
  export "${variable_name?}"
}

read_payload_value TF_VAR_github_app_id
read_payload_value TF_VAR_github_app_installation_id
read_payload_value TF_VAR_github_app_private_key
read_payload_value AWS_ACCESS_KEY_ID
read_payload_value AWS_SECRET_ACCESS_KEY

export TF_VAR_aws_access_key_id="$AWS_ACCESS_KEY_ID"
export TF_VAR_aws_secret_access_key="$AWS_SECRET_ACCESS_KEY"
export APEX_SYNC_SKIP_ENV_FILE=1
export TF_IN_AUTOMATION=1

echo "Starting Apex-Sync bootstrap for commit $EXPECTED_COMMIT"
"$REPO_ROOT/scripts/bootstrap.sh"

KUBECONFIG_SETTING="$(yq -er '.kubeconfig_path' "$REPO_ROOT/override-config/ansible.yaml")"
case "$KUBECONFIG_SETTING" in
  /*)
    KUBECONFIG_PATH="$KUBECONFIG_SETTING"
    ;;
  \~/*)
    KUBECONFIG_PATH="$HOME/${KUBECONFIG_SETTING:2}"
    ;;
  *)
    KUBECONFIG_PATH="$(realpath -m -- "$TERRAFORM_DIR/$KUBECONFIG_SETTING")"
    ;;
esac

if [[ ! -f "$KUBECONFIG_PATH" ]]; then
  echo "Kubeconfig not found after bootstrap: $KUBECONFIG_PATH"
  exit 1
fi

echo "Verifying Kubernetes cluster and Argo CD"
kubectl --kubeconfig "$KUBECONFIG_PATH" cluster-info
kubectl --kubeconfig "$KUBECONFIG_PATH" wait --for=condition=Ready nodes --all --timeout=5m
kubectl --kubeconfig "$KUBECONFIG_PATH" get nodes
kubectl --kubeconfig "$KUBECONFIG_PATH" -n argocd get pods
kubectl --kubeconfig "$KUBECONFIG_PATH" -n argocd get application app-of-apps
kubectl --kubeconfig "$KUBECONFIG_PATH" -n argocd get applications

echo "Apex-Sync bootstrap and verification completed successfully."
