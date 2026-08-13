#!/bin/sh
set -eu

INPUT_PATH="${INPUT_PATH:-/work/argocd-client-secret}"
SECRET_NAME="${SECRET_NAME:-argocd-oidc-client-secret}"
SECRET_NAMESPACE="${SECRET_NAMESPACE:-keycloak}"
REFLECTION_NAMESPACES="${REFLECTION_NAMESPACES:-argocd}"
PART_OF_LABEL="${PART_OF_LABEL:-argocd}"

client_secret="$(cat "$INPUT_PATH")"
encoded="$(printf "%s" "$client_secret" | base64 | tr -d '\n')"

if kubectl get secret "$SECRET_NAME" -n "$SECRET_NAMESPACE" >/dev/null 2>&1; then
  kubectl patch secret "$SECRET_NAME" -n "$SECRET_NAMESPACE" --type=merge \
    -p "{\"metadata\":{\"labels\":{\"app.kubernetes.io/part-of\":\"${PART_OF_LABEL}\"},\"annotations\":{\"reflector.v1.k8s.emberstack.com/reflection-allowed\":\"true\",\"reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces\":\"${REFLECTION_NAMESPACES}\",\"reflector.v1.k8s.emberstack.com/reflection-auto-enabled\":\"true\",\"reflector.v1.k8s.emberstack.com/reflection-auto-namespaces\":\"${REFLECTION_NAMESPACES}\"}},\"data\":{\"oidc.keycloak.clientSecret\":\"${encoded}\"}}"
else
  kubectl create -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${SECRET_NAMESPACE}
  labels:
    app.kubernetes.io/part-of: ${PART_OF_LABEL}
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
    reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "${REFLECTION_NAMESPACES}"
    reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
    reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "${REFLECTION_NAMESPACES}"
type: Opaque
data:
  oidc.keycloak.clientSecret: ${encoded}
EOF
fi
