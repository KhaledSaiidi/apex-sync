#!/bin/sh
set -eu

root_password="$(kubectl get secret mysql-cluster-secrets -n stateful-resources -o jsonpath='{.data.root}' | base64 -d)"
printf "%s" "$root_password" > /work/root-password

if kubectl get secret keycloak-db-credentials -n keycloak >/dev/null 2>&1; then
  keycloak_username="$(kubectl get secret keycloak-db-credentials -n keycloak -o jsonpath='{.data.username}' | base64 -d)"
  keycloak_password="$(kubectl get secret keycloak-db-credentials -n keycloak -o jsonpath='{.data.password}' | base64 -d)"
else
  keycloak_username="keycloak"
  keycloak_password="$(head -c 32 /dev/urandom | base64 | tr -d '\n')"
fi

kubectl create secret generic keycloak-db-credentials -n keycloak \
  --from-literal=root-password="$root_password" \
  --from-literal=username="$keycloak_username" \
  --from-literal=password="$keycloak_password" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

printf "%s" "$keycloak_username" > /work/keycloak-username
printf "%s" "$keycloak_password" > /work/keycloak-password
