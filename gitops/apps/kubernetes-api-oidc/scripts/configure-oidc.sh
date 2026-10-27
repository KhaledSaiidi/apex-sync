#!/bin/sh
set -eu

: "${OIDC_ISSUER_URL:?OIDC_ISSUER_URL is required}"
: "${OIDC_CLIENT_ID:?OIDC_CLIENT_ID is required}"

manifest=/host/etc/kubernetes/manifests/kube-apiserver.yaml
discovery_url="${OIDC_ISSUER_URL}/.well-known/openid-configuration"

if [ ! -f "$manifest" ]; then
  echo "Kube-apiserver static-pod manifest was not found: $manifest" >&2
  exit 1
fi

echo "Waiting for Keycloak OIDC discovery from the control-plane network namespace."
for attempt in $(seq 1 120); do
  if discovery="$(nsenter -t 1 -n -- curl --fail --silent --show-error --max-time 10 "$discovery_url" 2>/dev/null)" \
    && printf '%s' "$discovery" | jq -e --arg issuer "$OIDC_ISSUER_URL" '.issuer == $issuer and (.jwks_uri | type == "string")' >/dev/null; then
    break
  fi

  if [ "$attempt" -eq 120 ]; then
    echo "Timed out waiting for valid OIDC discovery at $discovery_url" >&2
    exit 1
  fi

  sleep 10
done

tmp_manifest="$(mktemp "${manifest}.XXXXXX")"
trap 'rm -f "$tmp_manifest"' EXIT

# kubeadm renders command arguments as a YAML sequence. Remove only arguments
# owned by this hook, then insert their desired values directly after the
# kube-apiserver command. The rename is atomic from kubelet's perspective.
awk -v issuer="$OIDC_ISSUER_URL" -v client_id="$OIDC_CLIENT_ID" '
  /^[[:space:]]*-[[:space:]]+--oidc-(issuer-url|client-id|username-claim|username-prefix|groups-claim|groups-prefix)=/ { next }
  {
    print
    if ($0 ~ /^[[:space:]]*-[[:space:]]+kube-apiserver[[:space:]]*$/) {
      match($0, /^[[:space:]]*/)
      indent = substr($0, RSTART, RLENGTH)
      print indent "- --oidc-issuer-url=" issuer
      print indent "- --oidc-client-id=" client_id
      print indent "- --oidc-username-claim=email"
      print indent "- --oidc-username-prefix=oidc:"
      print indent "- --oidc-groups-claim=groups"
      print indent "- --oidc-groups-prefix=oidc:"
    }
  }
' "$manifest" > "$tmp_manifest"

if ! grep -Fq -- "--oidc-issuer-url=${OIDC_ISSUER_URL}" "$tmp_manifest"; then
  echo "Could not locate the kube-apiserver command in $manifest" >&2
  exit 1
fi

if ! cmp -s "$manifest" "$tmp_manifest"; then
  mv "$tmp_manifest" "$manifest"
  trap - EXIT
  echo "Enabled Keycloak OIDC authentication in the kube-apiserver static pod."
else
  echo "Kube-apiserver OIDC arguments are already current."
fi

echo "Waiting for the Kubernetes API server to recover."
for attempt in $(seq 1 120); do
  if nsenter -t 1 -n -- curl --insecure --fail --silent --show-error --max-time 10 \
    https://127.0.0.1:6443/readyz >/dev/null 2>&1; then
    echo "Kubernetes API server is ready with OIDC enabled."
    exit 0
  fi

  sleep 5
done

echo "Kubernetes API server did not become ready after enabling OIDC." >&2
exit 1
