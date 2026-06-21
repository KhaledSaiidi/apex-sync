#!/bin/sh
set -eu

client_secret="$(cat /work/argocd-client-secret)"
encoded="$(printf "%s" "$client_secret" | base64 | tr -d '\n')"
secret_name="argocd-oidc-client-secret"
namespace="keycloak"

if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
  kubectl patch secret "$secret_name" -n "$namespace" --type=merge \
    -p "{\"metadata\":{\"labels\":{\"app.kubernetes.io/part-of\":\"argocd\"},\"annotations\":{\"reflector.v1.k8s.emberstack.com/reflection-allowed\":\"true\",\"reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces\":\"argocd\",\"reflector.v1.k8s.emberstack.com/reflection-auto-enabled\":\"true\",\"reflector.v1.k8s.emberstack.com/reflection-auto-namespaces\":\"argocd\"}},\"data\":{\"oidc.keycloak.clientSecret\":\"${encoded}\"}}"
else
  kubectl create -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${secret_name}
  namespace: ${namespace}
  labels:
    app.kubernetes.io/part-of: argocd
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
    reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "argocd"
    reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
    reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "argocd"
type: Opaque
data:
  oidc.keycloak.clientSecret: ${encoded}
EOF
fi
