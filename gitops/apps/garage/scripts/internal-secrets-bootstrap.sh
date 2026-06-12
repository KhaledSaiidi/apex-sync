#!/bin/sh
set -eu

garage_namespace="${GARAGE_NAMESPACE:?missing GARAGE_NAMESPACE}"

if ! kubectl get secret garage-rpc-secret -n "$garage_namespace" >/dev/null 2>&1; then
  kubectl create secret generic garage-rpc-secret \
    -n "$garage_namespace" \
    --from-literal=rpcSecret="$(tr -dc 'a-f0-9' </dev/urandom | head -c 64)"
fi

if ! kubectl get secret garage-admin-token -n "$garage_namespace" >/dev/null 2>&1; then
  kubectl create secret generic garage-admin-token \
    -n "$garage_namespace" \
    --from-literal=token="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 43)"
fi
