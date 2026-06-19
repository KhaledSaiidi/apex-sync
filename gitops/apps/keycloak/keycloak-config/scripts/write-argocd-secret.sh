#!/bin/sh
set -eu

client_secret="$(cat /work/argocd-client-secret)"
encoded="$(printf "%s" "$client_secret" | base64 | tr -d '\n')"

if kubectl get secret argocd-secret -n argocd >/dev/null 2>&1; then
  kubectl patch secret argocd-secret -n argocd --type=merge \
    -p "{\"data\":{\"oidc.keycloak.clientSecret\":\"${encoded}\"}}"
else
  kubectl create secret generic argocd-secret -n argocd \
    --from-literal=oidc.keycloak.clientSecret="$client_secret"
fi
