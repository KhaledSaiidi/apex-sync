#!/bin/sh
set -eu

garage_namespace="${GARAGE_NAMESPACE:?missing GARAGE_NAMESPACE}"
endpoint_url="${ENDPOINT_URL:?missing ENDPOINT_URL}"
region="${REGION:?missing REGION}"
garage_label_selector="${GARAGE_LABEL_SELECTOR:?missing GARAGE_LABEL_SELECTOR}"
targets="${GARAGE_TARGETS:?missing GARAGE_TARGETS}"

kubectl wait \
  --namespace "$garage_namespace" \
  --for=condition=ready pod \
  --selector "$garage_label_selector" \
  --timeout=600s

garage_pod="$(kubectl get pod \
  --namespace "$garage_namespace" \
  --selector "$garage_label_selector" \
  --output jsonpath='{.items[0].metadata.name}')"

if [ -z "$garage_pod" ]; then
  echo "Garage pod not found" >&2
  exit 1
fi

ensure_key() {
  existing_key_id=""

  if kubectl get secret "$current_secret_name" -n "$garage_namespace" >/dev/null 2>&1; then
    existing_key_id="$(kubectl get secret "$current_secret_name" -n "$garage_namespace" -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)"
  fi

  if [ -n "$existing_key_id" ] && kubectl exec -n "$garage_namespace" "$garage_pod" -- /garage key info "$existing_key_id" >/dev/null 2>&1; then
    printf '%s\n' "$existing_key_id"
  elif kubectl exec -n "$garage_namespace" "$garage_pod" -- /garage key info "$current_key_name" >/dev/null 2>&1; then
    printf '%s\n' "$current_key_name"
  else
    kubectl exec -n "$garage_namespace" "$garage_pod" -- /garage key create "$current_key_name" >/dev/null
    printf '%s\n' "$current_key_name"
  fi
}

wait_for_key() {
  WAIT_GARAGE_NAMESPACE="$garage_namespace" \
  WAIT_GARAGE_POD="$garage_pod" \
  WAIT_KEY_ID="$current_key_id" \
    timeout 180 sh -ec '
    until kubectl exec -n "$WAIT_GARAGE_NAMESPACE" "$WAIT_GARAGE_POD" -- /garage key info "$WAIT_KEY_ID" >/dev/null 2>&1; do
      sleep 5
    done
  '
}

ensure_bucket() {
  if ! kubectl exec -n "$garage_namespace" "$garage_pod" -- /garage bucket info "$current_bucket_name" >/dev/null 2>&1; then
    kubectl exec -n "$garage_namespace" "$garage_pod" -- /garage bucket create "$current_bucket_name" >/dev/null
  fi

  WAIT_GARAGE_NAMESPACE="$garage_namespace" \
  WAIT_GARAGE_POD="$garage_pod" \
  WAIT_BUCKET_NAME="$current_bucket_name" \
    timeout 180 sh -ec '
    until kubectl exec -n "$WAIT_GARAGE_NAMESPACE" "$WAIT_GARAGE_POD" -- /garage bucket info "$WAIT_BUCKET_NAME" >/dev/null 2>&1; do
      sleep 5
    done
  '

  WAIT_GARAGE_NAMESPACE="$garage_namespace" \
  WAIT_GARAGE_POD="$garage_pod" \
  WAIT_BUCKET_NAME="$current_bucket_name" \
  WAIT_KEY_ID="$current_key_id" \
    timeout 180 sh -ec '
    until kubectl exec -n "$WAIT_GARAGE_NAMESPACE" "$WAIT_GARAGE_POD" -- /garage bucket allow --key "$WAIT_KEY_ID" --read --write --owner "$WAIT_BUCKET_NAME" >/dev/null 2>&1; do
      sleep 5
    done
  '
}

read_key_material() {
  READ_GARAGE_NAMESPACE="$garage_namespace" \
  READ_GARAGE_POD="$garage_pod" \
  READ_KEY_ID="$current_key_id" \
  READ_OUTPUT_PREFIX="$current_secret_name" \
    timeout 180 sh -ec '
    while true; do
      if kubectl exec -n "$READ_GARAGE_NAMESPACE" "$READ_GARAGE_POD" -- /garage key info --show-secret "$READ_KEY_ID" >"/tmp/$READ_OUTPUT_PREFIX-key-info.txt" 2>/dev/null; then
        sed -n "s/^Key ID:[[:space:]]*//p" "/tmp/$READ_OUTPUT_PREFIX-key-info.txt" | sed -n "1p" >"/tmp/$READ_OUTPUT_PREFIX-access-key-id.txt"
        sed -n "s/^Secret key:[[:space:]]*//p" "/tmp/$READ_OUTPUT_PREFIX-key-info.txt" | sed -n "1p" >"/tmp/$READ_OUTPUT_PREFIX-secret-key.txt"

        if [ -s "/tmp/$READ_OUTPUT_PREFIX-access-key-id.txt" ] && [ -s "/tmp/$READ_OUTPUT_PREFIX-secret-key.txt" ]; then
          exit 0
        fi
      fi

      sleep 5
    done
  '
}

write_secret() {
  if [ ! -s "/tmp/$current_secret_name-access-key-id.txt" ] || [ ! -s "/tmp/$current_secret_name-secret-key.txt" ]; then
    echo "Failed to read Garage access key material for $current_secret_name" >&2
    exit 1
  fi

  kubectl create secret generic "$current_secret_name" \
    --namespace "$garage_namespace" \
    --from-literal=AWS_ACCESS_KEY_ID="$(cat "/tmp/$current_secret_name-access-key-id.txt")" \
    --from-literal=AWS_SECRET_ACCESS_KEY="$(cat "/tmp/$current_secret_name-secret-key.txt")" \
    --from-literal=AWS_ENDPOINT_URL="$endpoint_url" \
    --from-literal=AWS_REGION="$region" \
    --from-literal="$current_bucket_field=$current_buckets_csv" \
    --dry-run=client \
    -o yaml \
    | kubectl annotate --local -f - \
        reflector.v1.k8s.emberstack.com/reflection-allowed="true" \
        reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces="$current_reflection_namespaces" \
        reflector.v1.k8s.emberstack.com/reflection-auto-enabled="true" \
        reflector.v1.k8s.emberstack.com/reflection-auto-namespaces="$current_reflection_namespaces" \
        -o yaml \
    | kubectl apply -f -
}

printf '%s\n' "$targets" | while IFS='|' read -r current_secret_name current_key_name current_buckets_csv current_bucket_field current_reflection_namespaces; do
  [ -n "$current_secret_name" ] || continue

  current_key_id="$(ensure_key)"
  wait_for_key

  printf '%s\n' "$current_buckets_csv" | tr ',' '\n' | while IFS= read -r current_bucket_name; do
    [ -n "$current_bucket_name" ] || continue
    ensure_bucket
  done

  read_key_material
  write_secret
done
