#!/bin/sh
set -eu

secret_name="${PG_APP_SECRET_NAME:?missing PG_APP_SECRET_NAME}"
reflection_namespaces="${PG_APP_REFLECTION_NAMESPACES:?missing PG_APP_REFLECTION_NAMESPACES}"
namespace="$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)"

SECRET_NAME="$secret_name" \
NAMESPACE="$namespace" \
timeout 900 sh -ec '
  while :; do
    if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" >/tmp/pg-app-secret.yaml 2>/dev/null; then
      password="$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.password}")"
      user="$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.user}")"
      dbname="$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.dbname}")"
      uri="$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.uri}")"

      if [ -n "$password" ] && [ -n "$user" ] && [ -n "$dbname" ] && [ -n "$uri" ]; then
        exit 0
      fi
    fi

    sleep 5
  done
'

kubectl annotate secret "$secret_name" \
  --namespace "$namespace" \
  reflector.v1.k8s.emberstack.com/reflection-allowed="true" \
  reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces="$reflection_namespaces" \
  reflector.v1.k8s.emberstack.com/reflection-auto-enabled="true" \
  reflector.v1.k8s.emberstack.com/reflection-auto-namespaces="$reflection_namespaces" \
  --overwrite
